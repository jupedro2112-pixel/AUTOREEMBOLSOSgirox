// =====================================================================
// SITE WELCOME — cartel de bienvenida general de la nueva página.
//
// Qué anuncia:
//   - Esta es la nueva página de cargas y descargas (reemplaza al WhatsApp).
//   - 10% extra en todas las primeras cargas durante el primer mes.
//
// Cuándo se muestra:
//   - A TODOS los visitantes la primera vez que entran a la página, sin
//     importar cómo llegaron (link de acceso directo, registro, publicista).
//   - localStorage guarda si ya lo cerraron → no vuelve a aparecer en este
//     dispositivo.
//
// Cierre:
//   - Con la cruz (✕) o tocando fuera del cartel.
//   - Bloqueado los primeros 5 segundos para que lo puedan leer: la cruz
//     muestra la cuenta regresiva y, si intentan cerrar antes, aparece un
//     aviso con los segundos que faltan.
//
// Convive con el welcome de publicista: si ambos aplican, primero se muestra
// este cartel y, al cerrarlo, app.js dispara el flujo del publicista.
// =====================================================================
window.VIP = window.VIP || {};

VIP.siteWelcome = (function () {

    const LS_FLAG = 'vip_siteWelcomeSeen';
    const MIN_VISIBLE_MS = 5000;

    let _openedAt = 0;
    let _timerId = null;
    let _onClosed = null;

    function _alreadySeen() {
        try { return localStorage.getItem(LS_FLAG) === '1'; } catch (e) { return false; }
    }

    function _markSeen() {
        try { localStorage.setItem(LS_FLAG, '1'); } catch (e) {}
    }

    function _remainingSec() {
        return Math.max(0, Math.ceil((MIN_VISIBLE_MS - (Date.now() - _openedAt)) / 1000));
    }

    // Actualiza la cruz y la leyenda inferior según la cuenta regresiva.
    function _tick() {
        const closeBtn = document.getElementById('siteWelcomeCloseBtn');
        const hint     = document.getElementById('siteWelcomeHint');
        const rem = _remainingSec();

        if (rem > 0) {
            if (closeBtn) {
                closeBtn.textContent = rem;
                closeBtn.classList.add('sw-locked');
            }
            if (hint) hint.textContent = '⏳ Vas a poder cerrar este cartel en ' + rem + (rem === 1 ? ' segundo' : ' segundos') + '…';
            return;
        }

        if (_timerId) { clearInterval(_timerId); _timerId = null; }
        if (closeBtn) {
            closeBtn.textContent = '✕';
            closeBtn.classList.remove('sw-locked');
        }
        if (hint) hint.textContent = '✓ Ya podés cerrar el cartel con la ✕ o tocando afuera.';
        const notice = document.getElementById('siteWelcomeWaitNotice');
        if (notice) notice.style.display = 'none';
    }

    // Aviso cuando intentan cerrar antes de los 5 segundos.
    function _showWaitNotice() {
        const notice = document.getElementById('siteWelcomeWaitNotice');
        if (!notice) return;
        const rem = _remainingSec();
        notice.textContent = '⏳ Esperá ' + rem + (rem === 1 ? ' segundo' : ' segundos') + ' más para poder cerrar el cartel.';
        notice.style.display = 'block';
        // Reinicia la animación de sacudida para que se note en cada intento.
        notice.classList.remove('sw-shake');
        void notice.offsetWidth;
        notice.classList.add('sw-shake');
    }

    function _tryClose() {
        if (Date.now() - _openedAt < MIN_VISIBLE_MS) {
            _showWaitNotice();
            return;
        }
        _markSeen();
        VIP.ui.hideModal('siteWelcomeModal');
        if (typeof _onClosed === 'function') {
            const cb = _onClosed;
            _onClosed = null;
            cb();
        }
    }

    // Trigger principal. Devuelve true si mostró el cartel; onClosed se
    // ejecuta recién cuando el usuario lo cierra (para encadenar otros
    // modales sin que se pisen).
    function maybeShow(onClosed) {
        if (_alreadySeen()) return false;
        const modal = document.getElementById('siteWelcomeModal');
        if (!modal) return false;
        _onClosed = (typeof onClosed === 'function') ? onClosed : null;
        _openedAt = Date.now();
        VIP.ui.showModal('siteWelcomeModal');
        _tick();
        _timerId = setInterval(_tick, 250);
        return true;
    }

    // ---- Buscador de WhatsApp del equipo ----
    // El usuario migrado no sabe/recuerda a qué WhatsApp pedir su acceso:
    // completa su usuario y el server detecta el equipo por el INICIO del
    // nombre (config 'equiposWhatsapp' cargada desde el panel de admin).

    function _toggleTeamFinder() {
        const finder = document.getElementById('swTeamFinder');
        if (!finder) return;
        const visible = finder.style.display !== 'none';
        finder.style.display = visible ? 'none' : '';
        if (!visible) {
            const input = document.getElementById('swTeamUsername');
            if (input) setTimeout(() => input.focus(), 50);
        }
    }

    function _renderTeamResult(html) {
        const box = document.getElementById('swTeamResult');
        if (!box) return;
        box.innerHTML = html;
        box.style.display = '';
    }

    async function _searchTeam() {
        const input = document.getElementById('swTeamUsername');
        const btn = document.getElementById('swTeamSearchBtn');
        const username = input ? input.value.trim() : '';
        if (!username) {
            _renderTeamResult('<p style="margin:0; color:#ffb0b0; font-size:13px;">Escribí tu usuario primero.</p>');
            return;
        }
        if (btn) { btn.disabled = true; btn.textContent = '...'; }
        try {
            const resp = await fetch(`${VIP.config.API_URL}/api/config/equipo-whatsapp?username=${encodeURIComponent(username)}`);
            const data = await resp.json().catch(() => ({}));
            if (resp.ok && data.found && data.url) {
                _renderTeamResult(
                    '<div style="background:rgba(37,211,102,0.1); border:1px solid rgba(37,211,102,0.4); border-radius:8px; padding:12px; text-align:center;">' +
                        '<p style="margin:0 0 10px; font-size:13px;">✅ ¡Detectamos tu equipo! Tocá el botón y pedí tu acceso:</p>' +
                        '<a href="' + data.url + '" target="_blank" rel="noopener" ' +
                           'style="display:block; background:#25d366; color:#fff; font-weight:bold; text-decoration:none; padding:12px; border-radius:8px; font-size:14px;">' +
                            '💬 Hablar por WhatsApp' +
                        '</a>' +
                    '</div>'
                );
            } else if (resp.ok && !data.found) {
                _renderTeamResult('<p style="margin:0; color:#ffb0b0; font-size:13px;">❌ No detectamos tu equipo con ese usuario. Revisá que esté bien escrito (tal como lo usabas siempre).</p>');
            } else {
                _renderTeamResult('<p style="margin:0; color:#ffb0b0; font-size:13px;">Hubo un error, probá de nuevo en unos segundos.</p>');
            }
        } catch (e) {
            _renderTeamResult('<p style="margin:0; color:#ffb0b0; font-size:13px;">Error de conexión, probá de nuevo.</p>');
        } finally {
            if (btn) { btn.disabled = false; btn.textContent = 'Buscar'; }
        }
    }

    // Bind de eventos. Se llama una sola vez desde app.js.
    function init() {
        const modal = document.getElementById('siteWelcomeModal');
        const closeBtn = document.getElementById('siteWelcomeCloseBtn');
        if (closeBtn) closeBtn.addEventListener('click', _tryClose);
        if (modal) {
            // Tocar fuera del cartel (el overlay oscuro) también cierra.
            modal.addEventListener('click', function (e) {
                if (e.target === modal) _tryClose();
            });
        }

        const toggleBtn = document.getElementById('swTeamToggleBtn');
        const searchBtn = document.getElementById('swTeamSearchBtn');
        const usernameInput = document.getElementById('swTeamUsername');
        if (toggleBtn) toggleBtn.addEventListener('click', _toggleTeamFinder);
        if (searchBtn) searchBtn.addEventListener('click', _searchTeam);
        if (usernameInput) {
            usernameInput.addEventListener('keydown', function (e) {
                if (e.key === 'Enter') { e.preventDefault(); _searchTeam(); }
            });
        }
    }

    return {
        init: init,
        maybeShow: maybeShow
    };
})();
