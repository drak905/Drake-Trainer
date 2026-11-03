// Drake Trainer Web App
(function() {
  let allTrainers = [];
  let currentFilter = 'all';
  let currentQuery = '';

  // DOM Elements
  const cardsGrid = document.getElementById('cards-grid');
  const searchInput = document.getElementById('search-input');
  const clearSearchBtn = document.getElementById('clear-search');
  const filterChips = document.querySelectorAll('.chip');
  const totalCountEl = document.getElementById('total-count');
  const totalCountNav = document.getElementById('total-count-nav');
  const filteredCountEl = document.getElementById('filtered-count');
  const countAllEl = document.getElementById('count-all');
  const noMatchCard = document.getElementById('no-match-card');
  const noMatchQuery = document.getElementById('no-match-query');
  const btnSearchGoogle = document.getElementById('btn-search-google');
  const btnSearchSteam = document.getElementById('btn-search-steam');
  const btnSearchPcgw = document.getElementById('btn-search-pcgw');
  const btnRequestIssue = document.getElementById('btn-request-issue');

  // Detail Modal Elements
  const detailModal = document.getElementById('detail-modal');
  const modalClose = document.getElementById('modal-close');
  const modalImg = document.getElementById('modal-img');
  const modalTitle = document.getElementById('modal-title');
  const modalMeta = document.getElementById('modal-meta');
  const modalTags = document.getElementById('modal-tags');
  const modalHotkeysTbody = document.getElementById('modal-hotkeys-tbody');
  const modalDownloadBtn = document.getElementById('modal-download-btn');
  const modalGithubBtn = document.getElementById('modal-github-btn');

  // Web Search Modal Elements
  const webSearchModal = document.getElementById('web-search-modal');
  const btnWebSearchModal = document.getElementById('btn-web-search-modal');
  const webModalClose = document.getElementById('web-modal-close');
  const webSearchInput = document.getElementById('web-search-input');
  const modalBtnGoogle = document.getElementById('modal-btn-google');
  const modalBtnSteam = document.getElementById('modal-btn-steam');
  const modalBtnPcgw = document.getElementById('modal-btn-pcgw');
  const modalBtnReq = document.getElementById('modal-btn-req');

  // Initialize
  async function init() {
    try {
      const res = await fetch('data/trainers.json');
      if (!res.ok) throw new Error('Network error');
      allTrainers = await res.json();
    } catch (e) {
      console.warn('Loading fallback data...', e);
      allTrainers = getFallbackData();
    }

    // Set counts
    const count = allTrainers.length;
    if (totalCountEl) totalCountEl.textContent = count;
    if (totalCountNav) totalCountNav.textContent = count;
    if (countAllEl) countAllEl.textContent = count;
    if (filteredCountEl) filteredCountEl.textContent = count;

    renderCards(allTrainers);
    attachEvents();
  }

  // Render cards
  function renderCards(trainers) {
    cardsGrid.innerHTML = '';

    if (trainers.length === 0) {
      noMatchCard.classList.remove('hidden');
      noMatchQuery.textContent = currentQuery || 'No results';
      updateNoMatchLinks(currentQuery);
      filteredCountEl.textContent = '0';
      return;
    }

    noMatchCard.classList.add('hidden');
    filteredCountEl.textContent = trainers.length;

    trainers.forEach(trainer => {
      const card = document.createElement('div');
      card.className = 'game-card';

      const previewFeatures = trainer.features.slice(0, 3).map(f => `
        <li class="card-feature-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
          <span>${escapeHtml(f)}</span>
        </li>
      `).join('');

      card.innerHTML = `
        <div class="card-img-wrapper">
          <img src="${trainer.thumbnail}" alt="${escapeHtml(trainer.title)}" class="card-img" loading="lazy" onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 460 215%22><rect width=%22100%%22 height=%22100%%22 fill=%22%23111827%22/><text x=%2250%%22 y=%2250%%22 dominant-baseline=%22middle%22 text-anchor=%22middle%22 fill=%22%2338bdf8%22 font-family=%22sans-serif%22 font-size=%2222%22 font-weight=%22bold%22>${encodeURIComponent(trainer.title)}</text></svg>'">
          <div class="card-badges">
            <span class="badge-engine">${escapeHtml(trainer.engine)}</span>
            ${trainer.hasTranslation ? '<span class="badge-vi">VI Pack</span>' : ''}
          </div>
        </div>
        <div class="card-content">
          <div class="card-title-row">
            <h3 class="card-title">${escapeHtml(trainer.title)}</h3>
            <span class="card-version">${escapeHtml(trainer.version)}</span>
          </div>
          <ul class="card-features-list">
            ${previewFeatures}
          </ul>
          <div class="card-actions">
            <button class="btn-card-secondary btn-details" data-id="${trainer.id}">Controls & Info</button>
            <a href="${trainer.downloadUrl}" target="_blank" class="btn-card-primary">Download ZIP</a>
          </div>
        </div>
      `;

      card.querySelector('.btn-details').addEventListener('click', () => openModal(trainer));
      cardsGrid.appendChild(card);
    });
  }

  // Filter & Search logic
  function filterAndRender() {
    const q = currentQuery.trim().toLowerCase();
    
    const filtered = allTrainers.filter(t => {
      // Category filter
      let matchesFilter = true;
      if (currentFilter !== 'all') {
        if (currentFilter === 'Has Translation') {
          matchesFilter = t.hasTranslation;
        } else {
          matchesFilter = t.engine.toLowerCase().includes(currentFilter.toLowerCase()) ||
                          t.tags.some(tag => tag.toLowerCase().includes(currentFilter.toLowerCase()));
        }
      }

      if (!matchesFilter) return false;

      // Text query
      if (!q) return true;

      const titleMatch = t.title.toLowerCase().includes(q);
      const engineMatch = t.engine.toLowerCase().includes(q);
      const injectionMatch = t.injection.toLowerCase().includes(q);
      const tagsMatch = t.tags.some(tag => tag.toLowerCase().includes(q));
      const featuresMatch = t.features.some(f => f.toLowerCase().includes(q));
      const hotkeysMatch = t.hotkeys.some(h => h.key.toLowerCase().includes(q) || h.effect.toLowerCase().includes(q));

      return titleMatch || engineMatch || injectionMatch || tagsMatch || featuresMatch || hotkeysMatch;
    });

    renderCards(filtered);
  }

  // Update fallback web search links
  function updateNoMatchLinks(query) {
    const enc = encodeURIComponent(query + ' trainer');
    const encGame = encodeURIComponent(query);
    btnSearchGoogle.href = `https://www.google.com/search?q=${enc}`;
    btnSearchSteam.href = `https://store.steampowered.com/search/?term=${encGame}`;
    btnSearchPcgw.href = `https://www.pcgamingwiki.com/w/index.php?search=${encGame}`;
    btnRequestIssue.href = `https://github.com/drak905/Drake-Trainer/issues/new?title=${encodeURIComponent('[Trainer Request] ' + query)}&body=${encodeURIComponent('Game Name: ' + query + '\nPlatform: Steam / Epic / GOG\nEngine:\nDesired Features:\n')}`;
  }

  // Open detail modal
  function openModal(trainer) {
    modalImg.src = trainer.thumbnail;
    modalTitle.textContent = trainer.title;
    modalMeta.textContent = `${trainer.engine} • ${trainer.injection} • ${trainer.version}`;
    
    modalTags.innerHTML = trainer.tags.map(tag => 
      `<span class="badge-engine">${escapeHtml(tag)}</span>`
    ).join('');

    modalHotkeysTbody.innerHTML = trainer.hotkeys.map(h => `
      <tr>
        <td><span class="hotkey-badge">${escapeHtml(h.key)}</span></td>
        <td>${escapeHtml(h.effect)}</td>
      </tr>
    `).join('');

    modalDownloadBtn.href = trainer.downloadUrl;
    modalGithubBtn.href = `https://github.com/drak905/Drake-Trainer/tree/main/${trainer.repoFolder}`;

    detailModal.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
  }

  function closeModal() {
    detailModal.classList.add('hidden');
    webSearchModal.classList.add('hidden');
    document.body.style.overflow = '';
  }

  // Events
  function attachEvents() {
    // Search input
    searchInput.addEventListener('input', (e) => {
      currentQuery = e.target.value;
      if (currentQuery) {
        clearSearchBtn.classList.add('visible');
      } else {
        clearSearchBtn.classList.remove('visible');
      }
      filterAndRender();
    });

    clearSearchBtn.addEventListener('click', () => {
      searchInput.value = '';
      currentQuery = '';
      clearSearchBtn.classList.remove('visible');
      filterAndRender();
      searchInput.focus();
    });

    // Filter chips
    filterChips.forEach(chip => {
      chip.addEventListener('click', () => {
        filterChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        currentFilter = chip.dataset.filter;
        filterAndRender();
      });
    });

    // Modal close
    modalClose.addEventListener('click', closeModal);
    webModalClose.addEventListener('click', closeModal);
    detailModal.addEventListener('click', (e) => {
      if (e.target === detailModal) closeModal();
    });
    webSearchModal.addEventListener('click', (e) => {
      if (e.target === webSearchModal) closeModal();
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') closeModal();
    });

    // Web Search Modal trigger
    btnWebSearchModal.addEventListener('click', () => {
      webSearchModal.classList.remove('hidden');
      webSearchInput.value = currentQuery || '';
      document.body.style.overflow = 'hidden';
      webSearchInput.focus();
      updateWebModalActions();
    });

    webSearchInput.addEventListener('input', updateWebModalActions);

    function updateWebModalActions() {
      const q = webSearchInput.value.trim() || 'Game';
      modalBtnGoogle.textContent = `🔍 Search Google for "${q} trainer"`;
      modalBtnSteam.textContent = `🎮 Search Steam Store for "${q}"`;
      modalBtnPcgw.textContent = `📖 Search PCGamingWiki for "${q}"`;
      modalBtnReq.textContent = `💡 Request "${q}" Trainer on GitHub`;

      modalBtnGoogle.onclick = () => window.open(`https://www.google.com/search?q=${encodeURIComponent(q + ' trainer')}`, '_blank');
      modalBtnSteam.onclick = () => window.open(`https://store.steampowered.com/search/?term=${encodeURIComponent(q)}`, '_blank');
      modalBtnPcgw.onclick = () => window.open(`https://www.pcgamingwiki.com/w/index.php?search=${encodeURIComponent(q)}`, '_blank');
      modalBtnReq.onclick = () => window.open(`https://github.com/drak905/Drake-Trainer/issues/new?title=${encodeURIComponent('[Trainer Request] ' + q)}&body=${encodeURIComponent('Game Name: ' + q + '\nPlatform: Steam / Epic / GOG\nEngine:\nDesired Features:\n')}`, '_blank');
    }
  }

  function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // Offline / Local File protocol Fallback Data
  function getFallbackData() {
    return [
      {
        id: "afterimage",
        title: "Afterimage",
        thumbnail: "assets/thumbnails/afterimage.jpg",
        version: "v1.4.0",
        engine: "Unreal Engine 4",
        injection: "UE4SS Lua Mod (dwmapi.dll)",
        tags: ["Metroidvania", "Action", "Unreal Engine", "UE4SS", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Afterimage-Trainer-v1.4.0.zip",
        repoFolder: "trainers/01.Afterimage",
        features: ["In-Game HUD Menu (Home)", "God Mode (Spike/Trap Safe)", "Add +100 to All Bag Items (F2)", "Unlimited Air Jumps (F3)", "Interactive Minimap Item Radar (PgUp)"],
        hotkeys: [
          { key: "Home", effect: "Toggle In-Game Trainer HUD" },
          { key: "F1", effect: "God Mode (Invincible to hazards & bosses)" },
          { key: "F2", effect: "Add +100 to every bag inventory item (up to 999)" },
          { key: "F3", effect: "Unlimited Air Jumps" },
          { key: "F4", effect: "Infinite Weapon Skills & MP" },
          { key: "F5", effect: "2x Movement Speed" },
          { key: "PgUp", effect: "Map Item Markers (reveals chests & NPCs on minimap)" }
        ]
      },
      {
        id: "astral-ascent",
        title: "Astral Ascent",
        thumbnail: "assets/thumbnails/astral-ascent.jpg",
        version: "v1.0.0",
        engine: "Chowdren (C++)",
        injection: "Native Proxy DLL (winmm.dll)",
        tags: ["Roguelite", "Action", "Chowdren", "Native C++"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/AstralAscent-Trainer-v1.zip",
        repoFolder: "trainers/02.Astral-Ascent",
        features: ["In-Game Cheat/Debug Menu (F1)", "God Mode (Infinite HP & Mana)", "Unlimited Air Jumps", "One-Hit Kill", "Currency Modifiers"],
        hotkeys: [
          { key: "F1 or [ / ]", effect: "Open In-Game Cheat & Debug Menu" },
          { key: "1", effect: "Infinite HP" },
          { key: "2", effect: "Auto Kill Enemies (One-Hit Kill)" },
          { key: "3", effect: "Infinite Mana Lock" },
          { key: "4", effect: "Add 9,999 Quartz & Sun Crystals" }
        ]
      },
      {
        id: "bo-path-of-the-teal-lotus",
        title: "Bō: Path of the Teal Lotus",
        thumbnail: "assets/thumbnails/bo-path-of-the-teal-lotus.jpg",
        version: "v1.1.0",
        engine: "Unity Mono",
        injection: "BepInEx 5 + Harmony (winhttp.dll)",
        tags: ["Metroidvania", "Platformer", "Unity", "BepInEx", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Bo-Trainer-v1.zip",
        repoFolder: "trainers/03.Bo-Path-of-the-Teal-Lotus",
        features: ["God Mode (Spike/Freeze Immune)", "Unlimited Air Jump & Daruma Reset", "One-Hit Kill (Tengu Duo Safe)", "Infinite Tea Kettle Heal", "Kodama Map Overlay (F2)"],
        hotkeys: [
          { key: "F1", effect: "God Mode (Immune to spikes, falls, ice)" },
          { key: "F2", effect: "Kodama & Collectible Map Overlay" },
          { key: "F3", effect: "Add +5,000 Fox Fire Currency" },
          { key: "F4", effect: "Unlimited Jump / Infinite Daruma Reset" },
          { key: "F5", effect: "One-Hit Kill (Boss Safe)" },
          { key: "F6", effect: "Infinite Tea Kettle Healing" }
        ]
      },
      {
        id: "creature-in-the-well",
        title: "Creature in the Well",
        thumbnail: "assets/thumbnails/creature-in-the-well.jpg",
        version: "v1.0.0",
        engine: "Unreal Engine 4 (x64)",
        injection: "Native Proxy DLL (xinput1_3.dll)",
        tags: ["Action", "Pinball-Hack-and-Slash", "Unreal Engine", "Native C++"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/CITW-Trainer-v1.zip",
        repoFolder: "trainers/04.Creature-in-the-Well",
        features: ["God Mode / Invincibility", "Unlimited Energy", "Instant Weapon Charge", "One-Hit Core Overload", "Add Energy & Orbs"],
        hotkeys: [
          { key: "F1", effect: "God Mode (No damage from lasers or turrets)" },
          { key: "F2", effect: "Unlimited Energy Lock" },
          { key: "F3", effect: "Instant Max Weapon Charge" },
          { key: "F4", effect: "One-Hit Core Overload" },
          { key: "F5", effect: "Add 50,000 Power Energy" }
        ]
      },
      {
        id: "dead-cells",
        title: "Dead Cells",
        thumbnail: "assets/thumbnails/dead-cells.jpg",
        version: "v1.0.0",
        engine: "HashLink / Heaps",
        injection: "HashLink Bytecode Patcher",
        tags: ["Roguelite", "Metroidvania", "HashLink", "Bytecode Patch", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/DeadCells-Trainer-v1.zip",
        repoFolder: "trainers/05.Dead-Cells",
        features: ["God Mode (No Damage Lock)", "Infinite Gold & Cells", "Unlimited Jumps", "One-Hit Kill", "Instant Cooldowns"],
        hotkeys: [
          { key: "F1", effect: "Toggle God Mode" },
          { key: "F2", effect: "Infinite Gold (+100,000)" },
          { key: "F3", effect: "Infinite Cells (+1,000)" },
          { key: "F4", effect: "Unlimited Air Jumps" },
          { key: "F5", effect: "One-Hit Kill" }
        ]
      },
      {
        id: "deaths-gambit-afterlife",
        title: "Death's Gambit: Afterlife",
        thumbnail: "assets/thumbnails/deaths-gambit-afterlife.jpg",
        version: "v4.0.0",
        engine: "GameMaker Studio 2 (VM)",
        injection: "UTMT Hook + xdelta3 Delta Patch",
        tags: ["Souls-like", "Metroidvania", "GameMaker", "Bytecode Delta"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/DG-Afterlife-Trainer-v4-portable.zip",
        repoFolder: "trainers/06.Deaths-Gambit-Afterlife",
        features: ["God Mode + Infinite Feathers (F1)", "Infinite Endurance & Ammo (F2)", "Essence Pickup Bonus +999 (F3)", "Unlimited Air Jump (F4)", "Instant +99,999 Essence (G)"],
        hotkeys: [
          { key: "F1", effect: "God Mode + Infinite Healing Feathers" },
          { key: "F2", effect: "Infinite Endurance + Soul Energy + Ammo" },
          { key: "F3", effect: "Essence Pickup Bonus (+999 per pickup)" },
          { key: "F4", effect: "Unlimited Air Jumps" },
          { key: "F5", effect: "One-Hit Kill (Merchant-Safe)" },
          { key: "G", effect: "Instant +99,999 Ultra Essence & Auto-Save" }
        ]
      },
      {
        id: "ghost-song",
        title: "Ghost Song",
        thumbnail: "assets/thumbnails/ghost-song.jpg",
        version: "v2.0.0",
        engine: "Unity IL2CPP (DX11)",
        injection: "Native Proxy (version.dll) + ImGui DX11",
        tags: ["Metroidvania", "Atmospheric", "Unity IL2CPP", "ImGui Overlay", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/GhostSong-Trainer-v2.zip",
        repoFolder: "trainers/07.Ghost-Song",
        features: ["In-Game Dear ImGui Menu (Insert)", "God Mode", "Infinite Nanites & Consumables", "Unlimited Air Jumps", "Full Map & Icon Reveal"],
        hotkeys: [
          { key: "Insert or F10", effect: "Toggle In-Game Dear ImGui Overlay Menu" },
          { key: "F1", effect: "God Mode (No damage, cannot die)" },
          { key: "F2", effect: "Add Nanites (+10,000)" },
          { key: "F3", effect: "Infinite Nanites & Consumables Lock" },
          { key: "F4", effect: "Unlimited Air Jumps" },
          { key: "F5", effect: "2x Movement Speed" },
          { key: "F6", effect: "One-Hit Kill" },
          { key: "F9", effect: "Reveal Entire Map with All Items & Save Stations" }
        ]
      },
      {
        id: "guacamelee-stce",
        title: "Guacamelee! STCE",
        thumbnail: "assets/thumbnails/guacamelee-stce.jpg",
        version: "v1.0.0",
        engine: "Custom 2D C++ Engine",
        injection: "Native Proxy DLL (dinput8.dll)",
        tags: ["Metroidvania", "Brawler", "Native C++", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Guacamelee-STCE-Trainer-v1.zip",
        repoFolder: "trainers/08.Guacamelee-STCE",
        features: ["God Mode / Invincible Luchador", "Infinite Stamina", "Unlimited Special Moves", "Unlimited Air Jumps", "Add Coins", "One-Hit Kill"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Add Coins (+10,000)" },
          { key: "F3", effect: "Infinite Stamina & Special Moves" },
          { key: "F4", effect: "Unlimited Air Jumps" },
          { key: "F5", effect: "One-Hit Kill" }
        ]
      },
      {
        id: "gunslugs",
        title: "Gunslugs",
        thumbnail: "assets/thumbnails/gunslugs.png",
        version: "v1.0.0",
        engine: "Java 8 / LWJGL 2 (Packr)",
        injection: "URLClassLoader Classpath Override",
        tags: ["Run-and-Gun", "Retro", "Java / LWJGL", "Pixel HUD"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Gunslugs-Trainer-v1.zip",
        repoFolder: "trainers/09.Gunslugs",
        features: ["Native Pixel HUD & Toasts", "God Mode (F1)", "Add Money (F2)", "Unlimited Money & Items (F3)", "Full Level Radar / ESP (F6)", "Windows 11 Fullscreen Crash Fix"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Add Money (+500)" },
          { key: "F3", effect: "Unlimited Money & Ammo Lock" },
          { key: "F4", effect: "Unlimited Jump" },
          { key: "F5", effect: "2x Movement Speed" },
          { key: "F6", effect: "Full-Level Radar Bar & Objective ESP" },
          { key: "F7", effect: "One-Hit Kill" },
          { key: "F8", effect: "Cycle Next Weapon" }
        ]
      },
      {
        id: "gunslugs-2",
        title: "Gunslugs 2",
        thumbnail: "assets/thumbnails/gunslugs-2.png",
        version: "v1.0.0",
        engine: "Java 8 / LWJGL 2 (Packr)",
        injection: "URLClassLoader Classpath Override",
        tags: ["Run-and-Gun", "Retro", "Java / LWJGL", "Pixel HUD"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Gunslugs2-Trainer-v1.zip",
        repoFolder: "trainers/10.Gunslugs-2",
        features: ["In-Game Pixel HUD", "God Mode (F1)", "Add Coins (F2)", "Unlimited Money & Ammo (F3)", "Map Radar / Objective ESP (F6)", "Weapon Cycle (F8)"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Add Coins (+500)" },
          { key: "F3", effect: "Unlimited Coins & Ammo Lock" },
          { key: "F4", effect: "Unlimited Air Jump" },
          { key: "F5", effect: "2x Movement Speed" },
          { key: "F6", effect: "Map Radar / Objective ESP" },
          { key: "F7", effect: "One-Hit Kill" },
          { key: "F8", effect: "Cycle Weapon" }
        ]
      },
      {
        id: "gunslugs-3-rogue-tactics",
        title: "Gunslugs 3: Rogue Tactics",
        thumbnail: "assets/thumbnails/gunslugs-3.jpg",
        version: "v1.0.0",
        engine: "Java 8 / LWJGL (Packr)",
        injection: "URLClassLoader Classpath Override",
        tags: ["Stealth-Action", "Roguelike", "Java / LWJGL", "Pixel HUD"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Gunslugs3-Trainer-v1.zip",
        repoFolder: "trainers/11.Gunslugs-3-Rogue-Tactics",
        features: ["Retro HUD & Menus", "God Mode (F1)", "Add Money (F2)", "Unlimited Items & Ammo (F3)", "Full Level Map ESP (F6)", "One-Hit Kill (F7)"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Add Money (+500)" },
          { key: "F3", effect: "Unlimited Money & Items Lock" },
          { key: "F4", effect: "Unlimited Jump" },
          { key: "F5", effect: "2x Movement Speed" },
          { key: "F6", effect: "Full Level Map ESP" },
          { key: "F7", effect: "One-Hit Kill" },
          { key: "F8", effect: "Weapon Cycle" }
        ]
      },
      {
        id: "nine-years-of-shadows",
        title: "9 Years of Shadows",
        thumbnail: "assets/thumbnails/nine-years-of-shadows.jpg",
        version: "v1.2.2",
        engine: "Unity Mono",
        injection: "BepInEx 5 + Harmony (winhttp.dll)",
        tags: ["Metroidvania", "Pixel Art", "Unity", "BepInEx", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/NineYearsOfShadows-Trainer-v1.zip",
        repoFolder: "trainers/12.Nine-Years-of-Shadows",
        features: ["God Mode (Darkness/Hazard Immune)", "Infinite Armor & Shadow Gauge", "Unlimited Jumps", "Infinite Halberd Energy", "Add Light Crystals (+10k)"],
        hotkeys: [
          { key: "F1", effect: "God Mode (Immune to all hazards and curses)" },
          { key: "F2", effect: "Add Light Crystals (+10,000)" },
          { key: "F3", effect: "Infinite Armor & Halberd Energy" },
          { key: "F4", effect: "Unlimited Air Jumps" },
          { key: "F5", effect: "One-Hit Kill" }
        ]
      },
      {
        id: "ogu-and-the-secret-forest",
        title: "Ogu & the Secret Forest",
        thumbnail: "assets/thumbnails/ogu-and-the-secret-forest.jpg",
        version: "v1.0.0",
        engine: "Unity Mono",
        injection: "BepInEx 5 + Harmony (winhttp.dll)",
        tags: ["Adventure", "Puzzle", "Unity", "BepInEx"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Ogu-Trainer-v1.zip",
        repoFolder: "trainers/13.Ogu-and-the-Secret-Forest",
        features: ["God Mode (Infinite Hearts)", "Infinite Stamina / Unlimited Roll", "Unlimited Sprint & Jump", "Add Bugs & Coins", "One-Hit Kill"],
        hotkeys: [
          { key: "F1", effect: "God Mode (Infinite Hearts)" },
          { key: "F2", effect: "Add Bugs & Currency (+5,000)" },
          { key: "F3", effect: "Infinite Stamina Lock" },
          { key: "F4", effect: "Unlimited Jump / Sprint" },
          { key: "F5", effect: "One-Hit Kill" }
        ]
      },
      {
        id: "shogun-showdown",
        title: "Shogun Showdown",
        thumbnail: "assets/thumbnails/shogun-showdown.jpg",
        version: "v1.0.0",
        engine: "Unity 2021 Mono",
        injection: "BepInEx 5.4.23 + HarmonyX",
        tags: ["Turn-Based", "Deckbuilder", "Roguelike", "Unity", "BepInEx"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/ShogunShowdown-Trainer-v1.zip",
        repoFolder: "trainers/14.Shogun-Showdown",
        features: ["God Mode (F1)", "Infinite Money & Meta (F2)", "Special Move Cooldown Lock (F3)", "2x Character Move Distance (F4)", "No Tile Cooldown (F7)", "Reveal Sector Map (F9)"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Infinite Coins & Meta Currency" },
          { key: "F3", effect: "Unlimited Special Move (Dash/Jump)" },
          { key: "F4", effect: "2x Character Move Distance" },
          { key: "F5", effect: "2x Game Speed" },
          { key: "F6", effect: "Infinite Consumable Potions" },
          { key: "F7", effect: "No Tile Cooldown" },
          { key: "F8", effect: "One-Hit Kill" },
          { key: "F9", effect: "Reveal Entire Sector Map" }
        ]
      },
      {
        id: "voidwrought",
        title: "Voidwrought",
        thumbnail: "assets/thumbnails/voidwrought.jpg",
        version: "v1.0.0",
        engine: "Unity Mono",
        injection: "BepInEx 5 + Harmony (winhttp.dll)",
        tags: ["Metroidvania", "Cosmic Horror", "Unity", "BepInEx", "Has Translation"],
        hasTranslation: true,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/Voidwrought-Trainer-v1.zip",
        repoFolder: "trainers/15.Voidwrought",
        features: ["God Mode", "Infinite Void Souls / Currency", "Unlimited Air Jumps & Dash", "Infinite Healing / Ichor", "One-Hit Kill"],
        hotkeys: [
          { key: "F1", effect: "God Mode" },
          { key: "F2", effect: "Add Void Souls (+10,000)" },
          { key: "F3", effect: "Infinite Ichor & Healing" },
          { key: "F4", effect: "Unlimited Air Jumps & Dash" },
          { key: "F5", effect: "One-Hit Kill" }
        ]
      },
      {
        id: "wizard-of-legend",
        title: "Wizard of Legend",
        thumbnail: "assets/thumbnails/wizard-of-legend.jpg",
        version: "v1.0.0",
        engine: "Unity Mono",
        injection: "Mono.Cecil IL Injector",
        tags: ["Roguelike", "Spellcasting", "Unity", "IL Injector"],
        hasTranslation: false,
        downloadUrl: "https://github.com/drak905/Drake-Trainer/releases/download/v1.0.0/WizardofLegend-Trainer-v1.zip",
        repoFolder: "trainers/16.Wizard-of-Legend",
        features: ["Unlocks Native Debug Menu (Backspace)", "God Mode (2)", "Max Difficulty (1)", "Slow-Motion Speeds (3)", "Fullscreen Minimap (4)", "+9999 Gold & +999 Chaos Gems"],
        hotkeys: [
          { key: "Backspace", effect: "Toggle Developer Debug Menu UI" },
          { key: "1", effect: "Toggle Max Difficulty" },
          { key: "2", effect: "Toggle God Mode (Invincibility)" },
          { key: "3", effect: "Cycle Slow-Motion Speeds (0.25x, 0.5x, 1x)" },
          { key: "4", effect: "Toggle Fullscreen Minimap" },
          { key: "- / =", effect: "Camera Zoom Out / In" },
          { key: "Menu Action", effect: "+9999 Gold & +999 Chaos Gems" },
          { key: "Menu Action", effect: "Wrath of Developer (Instant kill all screen enemies)" },
          { key: "Menu Action", effect: "Unlock All Spells, Relics, and Robes" }
        ]
      }
    ];
  }

  // Start app
  document.addEventListener('DOMContentLoaded', init);
})();
