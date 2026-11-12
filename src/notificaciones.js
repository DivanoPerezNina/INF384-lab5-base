const net = require('net');

const comercios = new Map();

// Decisión 2: se reemplaza la librería ip (CVE-2024-29415, sin versión corregida)
// por net.BlockList, que viene con Node. Solo se usaba aquí.
const DESTINOS_INTERNOS = new net.BlockList();

[
  ['0.0.0.0', 8], // "esta red"
  ['10.0.0.0', 8], // privada
  ['100.64.0.0', 10], // CGNAT
  ['127.0.0.0', 8], // loopback
  ['169.254.0.0', 16], // link-local, incluye metadatos 169.254.169.254
  ['172.16.0.0', 12], // privada
  ['192.0.0.0', 24], // asignaciones IETF
  ['192.168.0.0', 16], // privada
  ['198.18.0.0', 15], // pruebas de red
  ['224.0.0.0', 4], // multicast
  ['240.0.0.0', 4], // reservada y broadcast
].forEach(([red, prefijo]) => DESTINOS_INTERNOS.addSubnet(red, prefijo, 'ipv4'));

[
  ['::', 128], // no especificada
  ['::1', 128], // loopback
  ['64:ff9b::', 96], // NAT64
  ['fc00::', 7], // ULA privada
  ['fe80::', 10], // link-local
  ['ff00::', 8], // multicast
].forEach(([red, prefijo]) => DESTINOS_INTERNOS.addSubnet(red, prefijo, 'ipv6'));

// ::ffff:7f00:1 es 127.0.0.1 escrito como IPv6. Se traduce a IPv4 antes de revisar.
function ipv4Mapeada(host) {
  const m = host.toLowerCase().match(/^(?:0{0,4}:){0,5}:?ffff:([0-9a-f]{1,4}):([0-9a-f]{1,4})$/);
  if (!m) return null;
  const alto = parseInt(m[1], 16);
  const bajo = parseInt(m[2], 16);
  return [alto >> 8, alto & 255, bajo >> 8, bajo & 255].join('.');
}

function esDestinoInterno(host) {
  const tipo = net.isIP(host);
  if (tipo === 4) return DESTINOS_INTERNOS.check(host, 'ipv4');
  if (tipo === 6) {
    const v4 = ipv4Mapeada(host);
    if (v4) return DESTINOS_INTERNOS.check(v4, 'ipv4');
    return DESTINOS_INTERNOS.check(host, 'ipv6');
  }
  return false;
}

function validarUrlNotificacion(valor) {
  let url;
  try {
    url = new URL(valor);
  } catch (e) {
    return { ok: false, error: 'url invalida' };
  }
  if (url.protocol !== 'https:') {
    return { ok: false, error: 'solo https' };
  }
  const host = url.hostname.replace(/^\[|\]$/g, '');
  if (host === 'localhost' || host.endsWith('.localhost')) {
    return { ok: false, error: 'destino interno' };
  }
  if (esDestinoInterno(host)) {
    return { ok: false, error: 'destino interno' };
  }
  return { ok: true, url: url.toString() };
}

function registrarComercio(comercio, urlNotificacion) {
  const resultado = validarUrlNotificacion(urlNotificacion);
  if (!resultado.ok) return resultado;
  comercios.set(comercio, resultado.url);
  return { ok: true, comercio, url: resultado.url };
}

function urlDeComercio(comercio) {
  return comercios.get(comercio) || null;
}

module.exports = { validarUrlNotificacion, registrarComercio, urlDeComercio, esDestinoInterno };
