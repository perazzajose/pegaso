// Horarios en castellano, fáciles de escribir para voluntarios.
// Formato: "Lu-Vi 09:00-12:00,15:00-19:00; Sá 09:00-13:00"  ·  "24h"  ·  "Lu,Mi,Vi 10:00-18:00"
// Días: Lu Ma Mi Ju Vi Sá Do  (también acepta Sa, Lun, Mie, etc.)
(function () {
  const DIAS = { lu: 1, ma: 2, mi: 3, ju: 4, vi: 5, sa: 6, sá: 6, do: 0 };
  const dia = s => DIAS[s.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").slice(0, 2)];
  const min = s => { const [h, m] = s.split(":").map(Number); return h * 60 + (m || 0); };

  function parse(txt) {
    if (!txt) return null;
    if (/^\s*24\s*h/i.test(txt)) return "24h";
    const reglas = [];
    for (const seg of txt.split(";")) {
      const m = seg.trim().match(/^([A-Za-zÁáÉéÍíÓóÚú,\-\s]+?)\s+([\d:,\-\s]+)$/);
      if (!m) continue;
      const dias = new Set();
      for (const parte of m[1].split(",")) {
        const [a, b] = parte.split("-").map(dia);
        if (a === undefined) continue;
        if (b === undefined) { dias.add(a); continue; }
        for (let d = a; ; d = (d + 1) % 7) { dias.add(d); if (d === b) break; }
      }
      const rangos = m[2].split(",").map(r => r.split("-").map(s => s.trim())).filter(r => r.length === 2).map(([x, y]) => [min(x), min(y)]);
      reglas.push({ dias, rangos });
    }
    return reglas.length ? reglas : null;
  }

  // Devuelve { estado: "abierta" | "cerrada" | "sin-dato", texto }
  window.estadoHorario = function (txt, ahora = new Date()) {
    const r = parse(txt);
    if (!r) return { estado: "sin-dato", texto: "Horario sin confirmar" };
    if (r === "24h") return { estado: "abierta", texto: "Abierta 24 horas" };
    const d = ahora.getDay(), t = ahora.getHours() * 60 + ahora.getMinutes();
    for (const regla of r) {
      if (!regla.dias.has(d)) continue;
      for (const [a, b] of regla.rangos) {
        if (t >= a && t < b) {
          const h = String(Math.floor(b / 60)).padStart(2, "0") + ":" + String(b % 60).padStart(2, "0");
          return { estado: "abierta", texto: "Abierta hasta las " + h };
        }
      }
    }
    return { estado: "cerrada", texto: "Cerrada ahora" };
  };
  window.horarioValido = txt => !txt || parse(txt) !== null;
})();
