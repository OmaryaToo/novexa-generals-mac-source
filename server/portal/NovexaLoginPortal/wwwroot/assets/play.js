(() => {
	const $ = (s, r = document) => r.querySelector(s);
	const $$ = (s, r = document) => [...r.querySelectorAll(s)];
	const store = { get: (k) => { try { return localStorage.getItem(k); } catch { return null; } }, set: (k, v) => { try { localStorage.setItem(k, v); } catch { /* private mode */ } } };
	const isAr = () => document.documentElement.lang === 'ar';
	const t = (ar, en) => (isAr() ? ar : en);

	/* language (same convention as novexa-jo.com: data-ar / data-en on every translatable node) */
	const langBtn = $('#langToggle');
	function applyLang(lang) {
		const root = document.documentElement;
		root.lang = lang; root.dir = lang === 'ar' ? 'rtl' : 'ltr';
		$$('[data-ar][data-en]').forEach((el) => { el.textContent = el.dataset[lang]; });
		$$('[data-aria-ar]').forEach((el) => el.setAttribute('aria-label', lang === 'ar' ? el.dataset.ariaAr : el.dataset.ariaEn));
		const title = $('title');
		if (title && title.dataset.ar) document.title = title.dataset[lang];
		if (langBtn) { langBtn.textContent = lang === 'ar' ? 'EN' : 'ع'; langBtn.setAttribute('aria-label', lang === 'ar' ? 'English' : 'العربية'); }
		store.set('novexa-play-lang', lang);
		document.dispatchEvent(new Event('langchange'));
	}
	if (langBtn) langBtn.addEventListener('click', () => applyLang(isAr() ? 'en' : 'ar'));
	applyLang(store.get('novexa-play-lang') === 'ar' ? 'ar' : 'en'); // English by default

	/* nav + reveal */
	const nav = $('.nav'), menuBtn = $('#menuBtn'), links = $('#navLinks');
	if (menuBtn) menuBtn.addEventListener('click', () => { const open = links.classList.toggle('open'); menuBtn.setAttribute('aria-expanded', String(open)); });
	const onScroll = () => nav && nav.classList.toggle('scrolled', scrollY > 8);
	addEventListener('scroll', onScroll, { passive: true }); onScroll();
	const y = $('#year'); if (y) y.textContent = new Date().getFullYear();
	if ('IntersectionObserver' in window) {
		const io = new IntersectionObserver((es) => es.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { rootMargin: '0px 0px -8% 0px' });
		$$('.rv').forEach((el) => io.observe(el));
	} else $$('.rv').forEach((el) => el.classList.add('in'));

	/* helpers */
	const fmt = (n) => new Intl.NumberFormat('en-US').format(n);
	const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
	const ago = (iso) => {
		if (!iso) return '—';
		const d = (Date.now() - new Date(iso + (iso.endsWith('Z') ? '' : 'Z')).getTime()) / 60000;
		const rtf = new Intl.RelativeTimeFormat(isAr() ? 'ar' : 'en', { numeric: 'auto' });
		if (d < 60) return rtf.format(-Math.max(1, Math.round(d)), 'minute');
		if (d < 1440) return rtf.format(-Math.round(d / 60), 'hour');
		return rtf.format(-Math.round(d / 1440), 'day');
	};
	const getJSON = (u) => fetch(u, { cache: 'no-store' }).then((r) => { if (!r.ok) throw new Error(r.status); return r.json(); });
	const set = (sel, v) => $$(sel).forEach((el) => { el.textContent = v; });

	/* live stats: any element with data-stat="key" */
	let lastStats = null;
	function paintStats() {
		const s = lastStats; if (!s) return;
		['players_online', 'lobbies', 'registered', 'matches_total', 'matches_today', 'new_players_week'].forEach((k) => set(`[data-stat="${k}"]`, fmt(s[k])));
		$$('[data-stat="status"]').forEach((el) => {
			el.textContent = s.online ? t('السيرفر يعمل', 'Server online') : t('السيرفر متوقف', 'Server offline');
			el.classList.toggle('off', !s.online);
		});
	}
	async function loadStats() {
		try { lastStats = await getJSON('/api/stats'); } catch { lastStats = lastStats ? { ...lastStats, online: false } : null; }
		paintStats();
	}
	if ($('[data-stat]')) { loadStats(); setInterval(() => { if (!document.hidden) loadStats(); }, 20000); }

	/* leaderboard */
	const lb = $('#leaderboard');
	let lbRows = null;
	function paintLb() {
		if (!lb || !lbRows) return;
		if (!lbRows.length) { lb.innerHTML = `<tr><td colspan="6" class="empty">${t('لا يوجد لاعبون بعد. كن أول من يسجّل!', 'No players yet. Be the first to sign in!')}</td></tr>`; return; }
		lb.innerHTML = lbRows.map((p, i) => {
			const games = p.wins + p.losses;
			const rate = games ? Math.round((p.wins / games) * 100) + '%' : '—';
			return `<tr class="${i < 3 ? 'top' : ''}"><td class="rank">${String(i + 1).padStart(2, '0')}</td><td class="name">${esc(p.name)}</td><td class="num">${fmt(p.elo)}</td><td class="num">${fmt(p.wins)} / ${fmt(p.losses)}</td><td class="num">${rate}</td><td>${p.last_match ? ago(p.last_match) : '—'}</td></tr>`;
		}).join('');
	}
	if (lb) getJSON('/api/leaderboard').then((r) => { lbRows = r; paintLb(); }).catch(() => { lb.innerHTML = `<tr><td colspan="6" class="empty">${t('تعذّر تحميل الترتيب.', 'Could not load the leaderboard.')}</td></tr>`; });

	/* recent matches */
	const rm = $('#recentMatches');
	let rmRows = null;
	function paintRm() {
		if (!rm || !rmRows) return;
		if (!rmRows.length) { rm.innerHTML = `<tr><td colspan="5" class="empty">${t('لم تُلعب أي مباراة بعد.', 'No matches played yet.')}</td></tr>`; return; }
		rm.innerHTML = rmRows.map((m) => `<tr><td class="num">#${m.id}</td><td class="name">${esc(m.map)}</td><td class="num">${m.players}</td><td class="num">${m.minutes} ${t('د', 'min')}</td><td>${ago(m.started)}</td></tr>`).join('');
	}
	if (rm) getJSON('/api/matches/recent').then((r) => { rmRows = r; paintRm(); }).catch(() => { rm.innerHTML = `<tr><td colspan="5" class="empty">${t('تعذّر تحميل المباريات.', 'Could not load matches.')}</td></tr>`; });

	/* download */
	const dlBtn = $('#dlBtn');
	let dl = null;
	function paintDl() {
		if (!dlBtn || !dl) return;
		if (!dl.available) {
			dlBtn.setAttribute('aria-disabled', 'true'); dlBtn.removeAttribute('href'); dlBtn.classList.add('soon');
			$('#dlLabel').textContent = t('قريباً', 'Coming soon');
			set('#dlVersion', '—'); set('#dlSize', '—'); set('#dlDate', '—');
			return;
		}
		dlBtn.href = dl.url;
		$('#dlLabel').textContent = t('حمّل اللانشر', 'Download the launcher');
		set('#dlVersion', dl.version || '—');
		set('#dlSize', (dl.size / 1048576).toFixed(1) + ' MB');
		set('#dlDate', new Date(dl.updated).toLocaleDateString(isAr() ? 'ar' : 'en-GB', { year: 'numeric', month: 'short', day: 'numeric' }));
		if (dl.notes) set('#dlNotes', dl.notes);
	}
	if (dlBtn) getJSON('/api/download').then((r) => { dl = r; paintDl(); }).catch(() => { dl = { available: false }; paintDl(); });

	document.addEventListener('langchange', () => { paintStats(); paintLb(); paintRm(); paintDl(); });
})();
