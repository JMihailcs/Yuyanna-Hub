// Cloudflare Worker para subir/servir imágenes y videos de Yuyanna Hub.
//
// - POST /upload        -> guarda el archivo en R2 y devuelve { url }
// - GET  /file/<clave>  -> sirve el archivo (con soporte de Range para video)
//
// Autorización de /upload: el cliente manda el ID token de Firebase del usuario
// (`Authorization: Bearer <idToken>`). El Worker verifica la firma con las
// claves PÚBLICAS de Google y luego consulta `admins/{uid}` en Firestore, que
// es la misma condición que `tieneRolAdmin()` en firestore.rules. No existe
// ningún secreto compartido: nada que extraer del APK ni del bundle web.
//
// Bindings/vars (ver wrangler.toml):
//   env.BUCKET               -> binding al bucket R2
//   env.FIREBASE_PROJECT_ID  -> id del proyecto Firebase (público, no es secreto)

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-Filename, Authorization, Range',
};

// Claves públicas con las que Google firma los ID tokens de Firebase.
const JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

// Tolerancia de reloj entre Google y el Worker, en segundos.
const MARGEN_RELOJ = 60;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS });
    }

    // ---- Subida ----
    if (request.method === 'POST' && url.pathname === '/upload') {
      let uid;
      try {
        uid = await autorizarAdmin(request, env);
      } catch (error) {
        return json({ error: error.message }, error.estado || 401);
      }

      const nombre = (request.headers.get('X-Filename') || 'archivo')
        .replace(/[^a-zA-Z0-9._-]/g, '_')
        .slice(-80);
      const clave = `${Date.now()}-${crypto.randomUUID().slice(0, 8)}-${nombre}`;
      const contentType =
        request.headers.get('Content-Type') || 'application/octet-stream';

      await env.BUCKET.put(clave, request.body, {
        httpMetadata: { contentType },
        // Queda registrado quién subió cada archivo.
        customMetadata: { subidoPor: uid },
      });

      return json({ url: `${url.origin}/file/${encodeURIComponent(clave)}` });
    }

    // ---- Servir ----
    if (request.method === 'GET' && url.pathname.startsWith('/file/')) {
      const clave = decodeURIComponent(url.pathname.slice('/file/'.length));
      const range = request.headers.get('Range');

      let opciones = {};
      if (range) {
        const m = /bytes=(\d+)-(\d*)/.exec(range);
        if (m) {
          const offset = parseInt(m[1], 10);
          opciones.range = m[2]
            ? { offset, length: parseInt(m[2], 10) - offset + 1 }
            : { offset };
        }
      }

      const obj = await env.BUCKET.get(clave, opciones);
      if (!obj) return new Response('No encontrado', { status: 404, headers: CORS });

      const headers = new Headers(CORS);
      obj.writeHttpMetadata(headers);
      headers.set('etag', obj.httpEtag);
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
      headers.set('Accept-Ranges', 'bytes');

      if (range && obj.range) {
        const start = obj.range.offset || 0;
        const length = obj.range.length || obj.size - start;
        const end = start + length - 1;
        headers.set('Content-Range', `bytes ${start}-${end}/${obj.size}`);
        return new Response(obj.body, { status: 206, headers });
      }
      return new Response(obj.body, { headers });
    }

    return new Response('Yuyanna upload worker', { headers: CORS });
  },
};

// --- Autorización -----------------------------------------------------------

/// Verifica el ID token del request y exige que el usuario tenga rol admin.
/// Devuelve el uid; lanza un error con `.estado` si no procede.
async function autorizarAdmin(request, env) {
  const proyecto = env.FIREBASE_PROJECT_ID;
  if (!proyecto) {
    throw fallo('El Worker no tiene configurado FIREBASE_PROJECT_ID.', 500);
  }

  const cabecera = request.headers.get('Authorization') || '';
  const idToken = cabecera.startsWith('Bearer ') ? cabecera.slice(7).trim() : '';
  if (!idToken) {
    throw fallo('Falta el ID token de Firebase.', 401);
  }

  const payload = await verificarIdToken(idToken, proyecto);
  if (!(await tieneRolAdmin(payload.sub, idToken, proyecto))) {
    throw fallo('Solo un administrador puede subir material.', 403);
  }
  return payload.sub;
}

/// Verifica firma, emisor, audiencia y vigencia de un ID token de Firebase.
async function verificarIdToken(idToken, proyecto) {
  const partes = idToken.split('.');
  if (partes.length !== 3) {
    throw fallo('El ID token está malformado.', 401);
  }
  const [cabecera64, payload64, firma64] = partes;

  const cabecera = decodificarJson(cabecera64);
  if (cabecera.alg !== 'RS256' || !cabecera.kid) {
    throw fallo('El ID token no usa RS256 con kid.', 401);
  }

  const jwk = await obtenerClave(cabecera.kid);
  if (!jwk) {
    throw fallo('El ID token fue firmado con una clave desconocida.', 401);
  }

  const clave = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const firmaValida = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    clave,
    base64UrlABytes(firma64),
    new TextEncoder().encode(`${cabecera64}.${payload64}`),
  );
  if (!firmaValida) {
    throw fallo('La firma del ID token no es válida.', 401);
  }

  const payload = decodificarJson(payload64);
  const ahora = Math.floor(Date.now() / 1000);
  if (payload.aud !== proyecto) {
    throw fallo('El ID token pertenece a otro proyecto.', 401);
  }
  if (payload.iss !== `https://securetoken.google.com/${proyecto}`) {
    throw fallo('El emisor del ID token no es Firebase.', 401);
  }
  if (typeof payload.sub !== 'string' || payload.sub === '') {
    throw fallo('El ID token no identifica a ningún usuario.', 401);
  }
  if (payload.exp <= ahora - MARGEN_RELOJ) {
    throw fallo('El ID token expiró; vuelve a iniciar sesión.', 401);
  }
  if (payload.iat > ahora + MARGEN_RELOJ) {
    throw fallo('El ID token viene del futuro.', 401);
  }
  return payload;
}

// Caché en memoria del JWKS: Google rota las claves cada pocas horas y anuncia
// la vigencia en Cache-Control, así que no hay que pedirlas en cada subida.
let jwksCache = { claves: null, expira: 0 };

async function obtenerClave(kid) {
  const ahora = Date.now();
  if (!jwksCache.claves || ahora >= jwksCache.expira) {
    const resp = await fetch(JWKS_URL);
    if (!resp.ok) {
      throw fallo('No se pudieron obtener las claves públicas de Google.', 503);
    }
    const cuerpo = await resp.json();
    const maxAge = /max-age=(\d+)/.exec(resp.headers.get('Cache-Control') || '');
    jwksCache = {
      claves: cuerpo.keys || [],
      expira: ahora + (maxAge ? parseInt(maxAge[1], 10) : 3600) * 1000,
    };
  }
  const clave = jwksCache.claves.find((k) => k.kid === kid);
  if (clave) {
    return clave;
  }
  // Un kid desconocido puede ser una rotación reciente: reintenta una vez.
  jwksCache = { claves: null, expira: 0 };
  const resp = await fetch(JWKS_URL);
  if (!resp.ok) {
    return null;
  }
  const cuerpo = await resp.json();
  jwksCache = { claves: cuerpo.keys || [], expira: ahora + 3600 * 1000 };
  return jwksCache.claves.find((k) => k.kid === kid) || null;
}

/// ¿El usuario tiene documento en `admins/{uid}`? Es la misma condición que
/// `tieneRolAdmin()` en firestore.rules, y la lectura va con el token del
/// propio usuario, así que las reglas siguen mandando (cada quien puede leer
/// su propio doc de admin).
async function tieneRolAdmin(uid, idToken, proyecto) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${proyecto}` +
    `/databases/(default)/documents/admins/${encodeURIComponent(uid)}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${idToken}` },
  });
  if (resp.status === 200) {
    return true;
  }
  if (resp.status === 403 || resp.status === 404) {
    return false;
  }
  throw fallo('No se pudo verificar el rol del usuario en Firestore.', 503);
}

// --- Utilidades -------------------------------------------------------------

function fallo(mensaje, estado) {
  const error = new Error(mensaje);
  error.estado = estado;
  return error;
}

function base64UrlABytes(valor) {
  const base64 = valor.replace(/-/g, '+').replace(/_/g, '/');
  const binario = atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, '='));
  const bytes = new Uint8Array(binario.length);
  for (let i = 0; i < binario.length; i++) {
    bytes[i] = binario.charCodeAt(i);
  }
  return bytes;
}

function decodificarJson(valor) {
  return JSON.parse(new TextDecoder().decode(base64UrlABytes(valor)));
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
