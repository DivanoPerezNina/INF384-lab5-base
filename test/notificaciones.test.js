const test = require('node:test');
const assert = require('node:assert');
const { validarUrlNotificacion, registrarComercio, urlDeComercio } = require('../src/notificaciones');

test('acepta una url publica https', () => {
  assert.strictEqual(validarUrlNotificacion('https://comercio.example.com/pagos').ok, true);
});

test('rechaza http', () => {
  assert.strictEqual(validarUrlNotificacion('http://comercio.example.com/pagos').ok, false);
});

test('rechaza una direccion privada', () => {
  assert.strictEqual(validarUrlNotificacion('https://10.0.0.8/pagos').ok, false);
  assert.strictEqual(validarUrlNotificacion('https://192.168.1.20/pagos').ok, false);
});

test('rechaza localhost', () => {
  assert.strictEqual(validarUrlNotificacion('https://localhost/pagos').ok, false);
  assert.strictEqual(validarUrlNotificacion('https://127.0.0.1/pagos').ok, false);
});

test('rechaza las variantes que evadian ip.isPrivate (CVE-2024-29415)', () => {
  const internas = [
    'https://[::ffff:127.0.0.1]/pagos',
    'https://[::ffff:7f00:1]/pagos',
    'https://[::1]/pagos',
    'https://[fd00::1]/pagos',
    'https://127.1/pagos',
    'https://0x7f000001/pagos',
    'https://017700000001/pagos',
    'https://0.0.0.0/pagos',
    'https://169.254.169.254/latest/meta-data',
    'https://100.64.0.1/pagos',
  ];
  for (const u of internas) {
    assert.strictEqual(validarUrlNotificacion(u).ok, false, u);
  }
});

test('sigue aceptando ip publicas', () => {
  assert.strictEqual(validarUrlNotificacion('https://8.8.8.8/pagos').ok, true);
  assert.strictEqual(validarUrlNotificacion('https://[2606:4700::1111]/pagos').ok, true);
});

test('registra la url del comercio', () => {
  const r = registrarComercio('bodega-lucha', 'https://bodega.example.com/aviso');
  assert.strictEqual(r.ok, true);
  assert.strictEqual(urlDeComercio('bodega-lucha'), 'https://bodega.example.com/aviso');
});
