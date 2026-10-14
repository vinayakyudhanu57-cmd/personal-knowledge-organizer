/**
 * Personal Knowledge Organizer — Frontend Interactive Controller
 * Connects with R Plumber API backend and handles UI state, search,
 * filtering, CRUD operations, and Related Notes Discovery.
 */

// Global Application State
const state = {
  items: [],
  totalItemsCount: 0,
  matchedCount: 0,
  dashboard: null,
  activeFilters: {
    q: '',
    topic: '',
    type: '',
    tag: '',
    importance: '',
    sortBy: 'updated_at',
    sortDir: 'desc'
  },
  selectedItem: null,
  isEditing: false,
  pendingDeleteId: null,
  backendConnected: false
};

// API Base URL (Relative path allows seamless serving via Plumber or proxy)
const API_BASE = '/api';

// DOM Element References
const elements = {
  backendStatus: document.getElementById('backend-status'),
  dashboardSection: document.getElementById('dashboard-section'),
  btnToggleDashboard: document.getElementById('btn-toggle-dashboard'),
  btnOpenCreateModal: document.getElementById('btn-open-create-modal'),

  // Dashboard Metrics
  statTotalItems: document.getElementById('stat-total-items'),
  statTopicsList: document.getElementById('stat-topics-list'),
  statImpHigh: document.getElementById('stat-imp-high'),
  statImpMed: document.getElementById('stat-imp-med'),
  statImpLow: document.getElementById('stat-imp-low'),
  statPopularTags: document.getElementById('stat-popular-tags'),

  // Search & Filter Controls
  searchInput: document.getElementById('search-input'),
  btnClearSearch: document.getElementById('btn-clear-search'),
  filterTopic: document.getElementById('filter-topic'),
  filterType: document.getElementById('filter-type'),
  filterTag: document.getElementById('filter-tag'),
  filterImportance: document.getElementById('filter-importance'),
  filterSort: document.getElementById('filter-sort'),
  btnResetFilters: document.getElementById('btn-reset-filters'),
  resultsCountText: document.getElementById('results-count-text'),
  activeFilterChips: document.getElementById('active-filter-chips'),

  // Grid & Empty State
  itemsGrid: document.getElementById('items-grid'),
  emptyState: document.getElementById('empty-state'),
  btnEmptyClear: document.getElementById('btn-empty-clear'),
  btnEmptyNew: document.getElementById('btn-empty-new'),

  // Detail Modal
  modalDetail: document.getElementById('modal-detail'),
  detailTypeBadge: document.getElementById('detail-type-badge'),
  detailTopicPill: document.getElementById('detail-topic-pill'),
  detailImportanceBadge: document.getElementById('detail-importance-badge'),
  detailTitle: document.getElementById('detail-title'),
  detailCreated: document.getElementById('detail-created'),
  detailUpdated: document.getElementById('detail-updated'),
  detailSourceWrapper: document.getElementById('detail-source-wrapper'),
  detailSourceLink: document.getElementById('detail-source-link'),
  detailContent: document.getElementById('detail-content'),
  detailTagsList: document.getElementById('detail-tags-list'),
  relatedStatusPill: document.getElementById('related-status-pill'),
  relatedNotesContainer: document.getElementById('related-notes-container'),
  btnDetailEdit: document.getElementById('btn-detail-edit'),
  btnDetailDelete: document.getElementById('btn-detail-delete'),

  // Form Modal
  modalForm: document.getElementById('modal-form'),
  formModalTitle: document.getElementById('form-modal-title'),
  knowledgeForm: document.getElementById('knowledge-form'),
  formItemId: document.getElementById('form-item-id'),
  inputTitle: document.getElementById('input-title'),
  inputItemType: document.getElementById('input-item-type'),
  inputTopic: document.getElementById('input-topic'),
  inputImportance: document.getElementById('input-importance'),
  inputSourceUrl: document.getElementById('input-source-url'),
  inputTags: document.getElementById('input-tags'),
  inputContent: document.getElementById('input-content'),
  formTagPreview: document.getElementById('form-tag-preview'),
  formErrorBanner: document.getElementById('form-error-banner'),
  topicDatalist: document.getElementById('topic-datalist'),

  // Delete Confirm Modal
  modalDeleteConfirm: document.getElementById('modal-delete-confirm'),
  deleteConfirmItemTitle: document.getElementById('delete-confirm-item-title'),
  btnConfirmDeleteAction: document.getElementById('btn-confirm-delete-action'),

  // Toast Container
  toastContainer: document.getElementById('toast-container')
};

// ==============================================================================
// 1. Initialization & Health Checking
// ==============================================================================

document.addEventListener('DOMContentLoaded', () => {
  initEventListeners();
  checkBackendHealth();
  loadDashboardData();
  fetchKnowledgeItems();
});

async function checkBackendHealth() {
  try {
    const res = await fetch(`${API_BASE}/health`);
    if (res.ok) {
      const data = await res.json();
      state.backendConnected = true;
      elements.backendStatus.classList.remove('error');
      elements.backendStatus.classList.add('connected');
      elements.backendStatus.querySelector('.status-label').textContent = `R Plumber (${data.items_count} items)`;
    } else {
      throw new Error(`HTTP ${res.status}`);
    }
  } catch (err) {
    state.backendConnected = false;
    elements.backendStatus.classList.remove('connected');
    elements.backendStatus.classList.add('error');
    elements.backendStatus.querySelector('.status-label').textContent = 'R Offline (Start R/main.R)';
    showToast('Cannot connect to R Plumber server. Ensure R/main.R is running on port 8000.', 'error');
  }
}

// ==============================================================================
// 2. Data Fetching (Items & Dashboard via R API)
// ==============================================================================

async function fetchKnowledgeItems() {
  const queryParams = new URLSearchParams();
  if (state.activeFilters.q) queryParams.set('q', state.activeFilters.q);
  if (state.activeFilters.topic) queryParams.set('topic', state.activeFilters.topic);
  if (state.activeFilters.type) queryParams.set('item_type', state.activeFilters.type);
  if (state.activeFilters.tag) queryParams.set('tag', state.activeFilters.tag);
  if (state.activeFilters.importance) queryParams.set('importance', state.activeFilters.importance);
  if (state.activeFilters.sortBy) queryParams.set('sort_by', state.activeFilters.sortBy);
  if (state.activeFilters.sortDir) queryParams.set('sort_dir', state.activeFilters.sortDir);

  try {
    const res = await fetch(`${API_BASE}/items?${queryParams.toString()}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    
    const data = await res.json();
    state.items = (data.items || []).map(normalizeItem);
    state.totalItemsCount = Array.isArray(data.total_items) ? data.total_items[0] : (data.total_items || 0);
    state.matchedCount = Array.isArray(data.matched_count) ? data.matched_count[0] : (data.matched_count || 0);
    
    renderItemsGrid();
    renderFilterMeta();
  } catch (err) {
    console.error('Failed to load items from R backend:', err);
    renderItemsGrid();
    elements.resultsCountText.textContent = 'Error connecting to R backend.';
  }
}

function normalizeItem(item) {
  if (!item) return null;
  const unwrap = (val, fb = '') => {
    if (val === null || val === undefined) return fb;
    if (Array.isArray(val)) return val.length > 0 ? val[0] : fb;
    return String(val);
  };

  let tags = [];
  if (Array.isArray(item.tags)) {
    tags = item.tags.flatMap(t => String(t).split(/[,;]+/)).map(t => t.trim().toLowerCase()).filter(Boolean);
  } else if (item.tags) {
    tags = String(item.tags).split(/[,;]+/).map(t => t.trim().toLowerCase()).filter(Boolean);
  }

  return {
    id: unwrap(item.id),
    title: unwrap(item.title),
    content: unwrap(item.content),
    item_type: unwrap(item.item_type, 'Note'),
    topic: unwrap(item.topic, 'General'),
    importance: unwrap(item.importance, 'Medium'),
    source_url: unwrap(item.source_url),
    created_at: unwrap(item.created_at),
    updated_at: unwrap(item.updated_at),
    tags: Array.from(new Set(tags))
  };
}

async function loadDashboardData() {
  try {
    const res = await fetch(`${API_BASE}/dashboard`);
    if (!res.ok) return;
    const dash = await res.json();
    state.dashboard = dash;
    renderDashboard(dash);
    populateTopicDatalist(dash);
    populateTopicAndTagSelects(dash);
  } catch (err) {
    console.warn('Dashboard load error:', err);
  }
}

// ==============================================================================
// 3. UI Rendering
// ==============================================================================

function renderDashboard(dash) {
  if (!dash) return;

  // Total items
  elements.statTotalItems.textContent = dash.total_items || 0;

  // Topics Breakdown
  elements.statTopicsList.innerHTML = '';
  const topics = Object.entries(dash.by_topic || {});
  if (topics.length === 0) {
    elements.statTopicsList.innerHTML = '<span class="placeholder-text">No topics yet</span>';
  } else {
    topics.forEach(([topicName, count]) => {
      const row = document.createElement('div');
      row.className = 'metric-list-item';
      row.style.cursor = 'pointer';
      row.title = `Filter by ${topicName}`;
      row.innerHTML = `<span>${escapeHtml(topicName)}</span><strong>${count}</strong>`;
      row.addEventListener('click', () => {
        setFilter('topic', topicName);
      });
      elements.statTopicsList.appendChild(row);
    });
  }

  // Importance Counts
  elements.statImpHigh.textContent = (dash.by_importance && dash.by_importance.High) || 0;
  elements.statImpMed.textContent = (dash.by_importance && dash.by_importance.Medium) || 0;
  elements.statImpLow.textContent = (dash.by_importance && dash.by_importance.Low) || 0;

  // Frequent Tags Cloud
  elements.statPopularTags.innerHTML = '';
  const tags = dash.top_tags || [];
  if (tags.length === 0) {
    elements.statPopularTags.innerHTML = '<span class="placeholder-text">No tags found</span>';
  } else {
    tags.forEach(tObj => {
      const chip = document.createElement('span');
      chip.className = 'tag-cloud-chip';
      chip.textContent = `#${tObj.tag} (${tObj.count})`;
      chip.title = `Filter notes tagged '${tObj.tag}'`;
      chip.addEventListener('click', () => {
        setFilter('tag', tObj.tag);
      });
      elements.statPopularTags.appendChild(chip);
    });
  }
}

function populateTopicDatalist(dash) {
  if (!dash || !dash.by_topic) return;
  elements.topicDatalist.innerHTML = '';
  Object.keys(dash.by_topic).forEach(topic => {
    const opt = document.createElement('option');
    opt.value = topic;
    elements.topicDatalist.appendChild(opt);
  });
}

function populateTopicAndTagSelects(dash) {
  if (!dash) return;

  // Save current selections
  const currentTopic = state.activeFilters.topic;
  const currentTag = state.activeFilters.tag;

  // Populate Topics
  elements.filterTopic.innerHTML = '<option value="">All Topics</option>';
  if (dash.by_topic) {
    Object.keys(dash.by_topic).sort().forEach(topic => {
      const opt = document.createElement('option');
      opt.value = topic;
      opt.textContent = `${topic} (${dash.by_topic[topic]})`;
      if (topic === currentTopic) opt.selected = true;
      elements.filterTopic.appendChild(opt);
    });
  }

  // Populate Tags
  elements.filterTag.innerHTML = '<option value="">All Tags</option>';
  if (dash.top_tags) {
    dash.top_tags.forEach(tObj => {
      const opt = document.createElement('option');
      opt.value = tObj.tag;
      opt.textContent = `#${tObj.tag} (${tObj.count})`;
      if (tObj.tag === currentTag) opt.selected = true;
      elements.filterTag.appendChild(opt);
    });
  }
}

function renderItemsGrid() {
  elements.itemsGrid.innerHTML = '';

  if (state.items.length === 0) {
    elements.emptyState.style.display = 'block';
    elements.itemsGrid.style.display = 'none';
    return;
  }

  elements.emptyState.style.display = 'none';
  elements.itemsGrid.style.display = 'grid';

  state.items.forEach(item => {
    const card = createNoteCard(item);
    elements.itemsGrid.appendChild(card);
  });
}

function createNoteCard(item) {
  const card = document.createElement('article');
  card.className = 'note-card';
  card.dataset.id = item.id;

  const itemTags = Array.isArray(item.tags) ? item.tags : [];
  const tagsHtml = itemTags.map(t => `<span class="tag-chip" data-tag="${escapeHtml(t)}">#${escapeHtml(t)}</span>`).join('');

  card.innerHTML = `
    <div class="card-main">
      <div class="card-header">
        <div class="card-meta-left">
          <span class="type-badge">${escapeHtml(item.item_type || 'Note')}</span>
          <span class="topic-pill">${escapeHtml(item.topic || 'General')}</span>
        </div>
        <span class="importance-badge ${escapeHtml(item.importance)}">${escapeHtml(item.importance)}</span>
      </div>

      <h3 class="card-title">${escapeHtml(item.title)}</h3>
      <p class="card-excerpt">${escapeHtml(item.content)}</p>

      ${tagsHtml ? `<div class="card-tags">${tagsHtml}</div>` : ''}
    </div>

    <div class="card-footer">
      <span class="card-date" title="Updated on ${escapeHtml(item.updated_at)}">
        Updated ${escapeHtml(item.updated_at)}
      </span>
      <div class="card-footer-actions">
        <button class="btn btn-secondary btn-sm btn-view-note" type="button">
          View &amp; Related
        </button>
        <button class="btn-icon-link edit-note" type="button" title="Edit this note" aria-label="Edit note">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 20h9"></path>
            <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"></path>
          </svg>
        </button>
        <button class="btn-icon-link delete delete-note" type="button" title="Delete this note" aria-label="Delete note">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="3 6 5 6 21 6"></polyline>
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
          </svg>
        </button>
      </div>
    </div>
  `;

  // Attach card event listeners
  const titleEl = card.querySelector('.card-title');
  const btnView = card.querySelector('.btn-view-note');
  titleEl.addEventListener('click', () => openDetailModal(item));
  btnView.addEventListener('click', () => openDetailModal(item));

  const btnEdit = card.querySelector('.edit-note');
  btnEdit.addEventListener('click', (e) => {
    e.stopPropagation();
    openEditModal(item);
  });

  const btnDelete = card.querySelector('.delete-note');
  btnDelete.addEventListener('click', (e) => {
    e.stopPropagation();
    promptDelete(item);
  });

  // Clicking any tag chip inside a card filters by that tag
  card.querySelectorAll('.tag-chip').forEach(chip => {
    chip.addEventListener('click', (e) => {
      e.stopPropagation();
      setFilter('tag', chip.dataset.tag);
    });
  });

  return card;
}

function renderFilterMeta() {
  // Results counter
  const total = state.totalItemsCount;
  const matched = state.matchedCount;

  if (total === 0) {
    elements.resultsCountText.textContent = 'Knowledge library is empty.';
  } else if (hasActiveFilters()) {
    elements.resultsCountText.innerHTML = `Showing <strong>${matched}</strong> of <strong>${total}</strong> knowledge items matching current filters.`;
  } else {
    elements.resultsCountText.innerHTML = `Showing all <strong>${total}</strong> saved knowledge items.`;
  }

  // Active filter pills
  elements.activeFilterChips.innerHTML = '';
  const f = state.activeFilters;

  if (f.q) {
    addActiveChip(`Search: "${f.q}"`, () => {
      state.activeFilters.q = '';
      elements.searchInput.value = '';
      elements.btnClearSearch.style.display = 'none';
      fetchKnowledgeItems();
    });
  }
  if (f.topic) {
    addActiveChip(`Topic: ${f.topic}`, () => {
      state.activeFilters.topic = '';
      elements.filterTopic.value = '';
      fetchKnowledgeItems();
    });
  }
  if (f.type) {
    addActiveChip(`Type: ${f.type}`, () => {
      state.activeFilters.type = '';
      elements.filterType.value = '';
      fetchKnowledgeItems();
    });
  }
  if (f.tag) {
    addActiveChip(`Tag: #${f.tag}`, () => {
      state.activeFilters.tag = '';
      elements.filterTag.value = '';
      fetchKnowledgeItems();
    });
  }
  if (f.importance) {
    addActiveChip(`Importance: ${f.importance}`, () => {
      state.activeFilters.importance = '';
      elements.filterImportance.value = '';
      fetchKnowledgeItems();
    });
  }
}

function addActiveChip(label, onRemove) {
  const chip = document.createElement('span');
  chip.className = 'active-chip';
  chip.innerHTML = `${escapeHtml(label)} <button type="button" aria-label="Remove filter">&times;</button>`;
  chip.querySelector('button').addEventListener('click', onRemove);
  elements.activeFilterChips.appendChild(chip);
}

function hasActiveFilters() {
  const f = state.activeFilters;
  return Boolean(f.q || f.topic || f.type || f.tag || f.importance);
}

// ==============================================================================
// 4. Detail View & Related Notes Discovery
// ==============================================================================

async function openDetailModal(rawItem) {
  const item = normalizeItem(rawItem);
  state.selectedItem = item;

  elements.detailTitle.textContent = item.title;
  elements.detailTypeBadge.textContent = item.item_type;
  elements.detailTopicPill.textContent = item.topic;
  elements.detailImportanceBadge.textContent = item.importance;
  elements.detailImportanceBadge.className = `importance-badge ${item.importance}`;
  elements.detailCreated.textContent = item.created_at || '--';
  elements.detailUpdated.textContent = item.updated_at || '--';

  // Source URL
  if (item.source_url && item.source_url.trim()) {
    elements.detailSourceWrapper.style.display = 'inline-flex';
    elements.detailSourceLink.href = item.source_url;
  } else {
    elements.detailSourceWrapper.style.display = 'none';
  }

  // Content (Preserving line breaks safely)
  elements.detailContent.textContent = item.content;

  // Tags
  elements.detailTagsList.innerHTML = '';
  const itemTags = Array.isArray(item.tags) ? item.tags : [];
  if (itemTags.length === 0) {
    elements.detailTagsList.innerHTML = '<span class="text-muted" style="font-size: 0.8rem;">No tags assigned.</span>';
  } else {
    itemTags.forEach(t => {
      const chip = document.createElement('span');
      chip.className = 'tag-chip';
      chip.textContent = `#${t}`;
      chip.addEventListener('click', () => {
        closeModal(elements.modalDetail);
        setFilter('tag', t);
      });
      elements.detailTagsList.appendChild(chip);
    });
  }

  // Fetch Related Notes in R
  loadRelatedNotes(item.id);

  // Detail Modal Actions
  elements.btnDetailEdit.onclick = () => {
    closeModal(elements.modalDetail);
    openEditModal(item);
  };
  elements.btnDetailDelete.onclick = () => {
    closeModal(elements.modalDetail);
    promptDelete(item);
  };

  openModal(elements.modalDetail);
}

async function loadRelatedNotes(itemId) {
  elements.relatedStatusPill.textContent = 'Calculating in R...';
  elements.relatedNotesContainer.innerHTML = '<div style="padding: 12px; font-size: 0.85rem; color: var(--text-muted);">Querying R backend for deterministic tag overlap...</div>';

  try {
    const res = await fetch(`${API_BASE}/related/${encodeURIComponent(itemId)}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    elements.relatedStatusPill.textContent = `${data.count} Related`;

    if (data.count === 0) {
      elements.relatedNotesContainer.innerHTML = `
        <div style="padding: 12px; font-size: 0.85rem; color: var(--text-secondary); background: var(--bg-surface); border-radius: var(--radius-sm); border: 1px dashed var(--border-subtle);">
          ${escapeHtml(data.message || 'No related notes share tags with this item.')}
        </div>
      `;
      return;
    }

    elements.relatedNotesContainer.innerHTML = '';
    data.notes.forEach(rel => {
      const relItem = document.createElement('div');
      relItem.className = 'related-note-item';
      relItem.innerHTML = `
        <div class="related-item-header">
          <span class="related-item-title">${escapeHtml(rel.title)}</span>
          <span class="related-item-score" title="Weighted tag overlap score">${rel.score}% Match</span>
        </div>
        <div class="related-item-reason">${escapeHtml(rel.reason)}</div>
        <div class="related-item-shared-tags">
          ${rel.shared_tags.map(st => `<span class="shared-tag-chip">#${escapeHtml(st)}</span>`).join('')}
        </div>
      `;

      // Clicking a related note switches the detail view to that note!
      relItem.addEventListener('click', async () => {
        try {
          const detailRes = await fetch(`${API_BASE}/items/${encodeURIComponent(rel.id)}`);
          if (detailRes.ok) {
            const nextItem = await detailRes.json();
            openDetailModal(nextItem);
          }
        } catch (e) {
          console.error('Failed to navigate to related note:', e);
        }
      });

      elements.relatedNotesContainer.appendChild(relItem);
    });

  } catch (err) {
    console.error('Failed to load related notes:', err);
    elements.relatedStatusPill.textContent = 'Unavailable';
    elements.relatedNotesContainer.innerHTML = '<div style="padding: 12px; font-size: 0.85rem; color: var(--danger-text);">Unable to compute related notes from R backend.</div>';
  }
}

// ==============================================================================
// 5. Add / Edit Form Handling
// ==============================================================================

function openCreateModal() {
  state.isEditing = false;
  elements.formModalTitle.textContent = 'New Knowledge Item';
  elements.formItemId.value = '';
  elements.knowledgeForm.reset();
  elements.formTagPreview.innerHTML = '';
  elements.formErrorBanner.style.display = 'none';
  elements.inputItemType.value = 'Note';
  elements.inputImportance.value = 'Medium';
  openModal(elements.modalForm);
  setTimeout(() => elements.inputTitle.focus(), 100);
}

function openEditModal(item) {
  state.isEditing = true;
  elements.formModalTitle.textContent = 'Edit Knowledge Item';
  elements.formItemId.value = item.id;
  elements.inputTitle.value = item.title;
  elements.inputItemType.value = item.item_type;
  elements.inputTopic.value = item.topic;
  elements.inputImportance.value = item.importance;
  elements.inputSourceUrl.value = item.source_url || '';
  elements.inputTags.value = Array.isArray(item.tags) ? item.tags.join(', ') : (item.tags || '');
  elements.inputContent.value = item.content;
  elements.formErrorBanner.style.display = 'none';

  updateFormTagPreview();
  openModal(elements.modalForm);
  setTimeout(() => elements.inputTitle.focus(), 100);
}

function updateFormTagPreview() {
  const raw = elements.inputTags.value;
  elements.formTagPreview.innerHTML = '';
  if (!raw.trim()) return;

  const tags = raw.split(/[,;]+/).map(t => t.trim().toLowerCase()).filter(t => t.length > 0);
  const unique = Array.from(new Set(tags));
  unique.forEach(t => {
    const chip = document.createElement('span');
    chip.className = 'shared-tag-chip';
    chip.textContent = `#${t}`;
    elements.formTagPreview.appendChild(chip);
  });
}

elements.inputTags.addEventListener('input', updateFormTagPreview);

elements.knowledgeForm.addEventListener('submit', async (e) => {
  e.preventDefault();

  const title = elements.inputTitle.value.trim();
  const content = elements.inputContent.value.trim();
  const itemType = elements.inputItemType.value.trim();
  const topic = elements.inputTopic.value.trim();
  const importance = elements.inputImportance.value.trim();
  const sourceUrl = elements.inputSourceUrl.value.trim();
  const tags = elements.inputTags.value.trim();
  const itemId = elements.formItemId.value.trim();

  // Basic client-side pre-validation
  const errors = [];
  if (!title) errors.push('Title is required.');
  if (title.length > 200) errors.push('Title must be 200 characters or fewer.');
  if (!content) errors.push('Note content / explanation is required.');
  if (!topic) errors.push('Topic / Category is required.');
  if (sourceUrl && !/^https?:\/\/.+/i.test(sourceUrl)) {
    errors.push('Source URL must begin with http:// or https://');
  }

  if (errors.length > 0) {
    elements.formErrorBanner.textContent = errors.join(' ');
    elements.formErrorBanner.style.display = 'block';
    return;
  }

  elements.formErrorBanner.style.display = 'none';

  const payload = {
    title,
    content,
    item_type: itemType,
    topic,
    importance,
    source_url: sourceUrl,
    tags
  };

  const isEdit = state.isEditing && Boolean(itemId);
  const endpoint = isEdit ? `${API_BASE}/items/${encodeURIComponent(itemId)}` : `${API_BASE}/items`;
  const method = isEdit ? 'PUT' : 'POST';

  try {
    const res = await fetch(endpoint, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    if (!res.ok || !data.success) {
      const msg = (data.errors && data.errors.join(' ')) || 'Failed to save item.';
      elements.formErrorBanner.textContent = msg;
      elements.formErrorBanner.style.display = 'block';
      return;
    }

    closeModal(elements.modalForm);
    showToast(isEdit ? 'Knowledge item updated successfully.' : 'New knowledge item added to library.', 'success');

    // Refresh UI data from R backend
    await fetchKnowledgeItems();
    await loadDashboardData();
  } catch (err) {
    console.error('Error saving item:', err);
    elements.formErrorBanner.textContent = 'Server connection error. Please ensure R/main.R is running.';
    elements.formErrorBanner.style.display = 'block';
  }
});

// ==============================================================================
// 6. Delete Confirmation & Execution
// ==============================================================================

function promptDelete(item) {
  state.pendingDeleteId = item.id;
  elements.deleteConfirmItemTitle.textContent = `"${item.title}" (${item.item_type} — ${item.topic})`;
  openModal(elements.modalDeleteConfirm);
}

elements.btnConfirmDeleteAction.addEventListener('click', async () => {
  if (!state.pendingDeleteId) return;

  const id = state.pendingDeleteId;
  try {
    const res = await fetch(`${API_BASE}/items/${encodeURIComponent(id)}`, {
      method: 'DELETE'
    });

    const data = await res.json();
    if (!res.ok || !data.success) {
      throw new Error((data.errors && data.errors.join(' ')) || 'Delete failed');
    }

    closeModal(elements.modalDeleteConfirm);
    showToast('Knowledge item deleted from CSV.', 'success');

    state.pendingDeleteId = null;
    await fetchKnowledgeItems();
    await loadDashboardData();
  } catch (err) {
    console.error('Delete error:', err);
    showToast(`Failed to delete: ${err.message}`, 'error');
  }
});

// ==============================================================================
// 7. Event Listeners & Search/Filter Controls
// ==============================================================================

function initEventListeners() {
  // Search input debounced
  let debounceTimer = null;
  elements.searchInput.addEventListener('input', (e) => {
    const val = e.target.value;
    elements.btnClearSearch.style.display = val.length > 0 ? 'block' : 'none';

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      state.activeFilters.q = val.trim();
      fetchKnowledgeItems();
    }, 250);
  });

  // Clear search button
  elements.btnClearSearch.addEventListener('click', () => {
    elements.searchInput.value = '';
    elements.btnClearSearch.style.display = 'none';
    state.activeFilters.q = '';
    fetchKnowledgeItems();
    elements.searchInput.focus();
  });

  // Topic filter
  elements.filterTopic.addEventListener('change', (e) => {
    state.activeFilters.topic = e.target.value;
    fetchKnowledgeItems();
  });

  // Type filter
  elements.filterType.addEventListener('change', (e) => {
    state.activeFilters.type = e.target.value;
    fetchKnowledgeItems();
  });

  // Tag filter
  elements.filterTag.addEventListener('change', (e) => {
    state.activeFilters.tag = e.target.value;
    fetchKnowledgeItems();
  });

  // Importance filter
  elements.filterImportance.addEventListener('change', (e) => {
    state.activeFilters.importance = e.target.value;
    fetchKnowledgeItems();
  });

  // Sort order
  elements.filterSort.addEventListener('change', (e) => {
    const [sortBy, sortDir] = e.target.value.split(':');
    state.activeFilters.sortBy = sortBy;
    state.activeFilters.sortDir = sortDir;
    fetchKnowledgeItems();
  });

  // Reset all filters button
  elements.btnResetFilters.addEventListener('click', resetAllFilters);
  elements.btnEmptyClear.addEventListener('click', resetAllFilters);

  // New item buttons
  elements.btnOpenCreateModal.addEventListener('click', openCreateModal);
  elements.btnEmptyNew.addEventListener('click', openCreateModal);

  // Dashboard Toggle
  elements.btnToggleDashboard.addEventListener('click', () => {
    const isCollapsed = elements.dashboardSection.classList.toggle('collapsed');
    elements.btnToggleDashboard.setAttribute('aria-expanded', !isCollapsed);
  });

  // Generic Modal Close handler on backdrop and [data-close-modal] buttons
  document.querySelectorAll('[data-close-modal]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const modal = e.target.closest('.modal-backdrop');
      if (modal) closeModal(modal);
    });
  });

  document.querySelectorAll('.modal-backdrop').forEach(modal => {
    modal.addEventListener('click', (e) => {
      if (e.target === modal) closeModal(modal);
    });
  });

  // Close modals on Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const openModalEl = document.querySelector('.modal-backdrop.active');
      if (openModalEl) closeModal(openModalEl);
    }
  });
}

function setFilter(key, value) {
  state.activeFilters[key] = value;
  if (key === 'topic') elements.filterTopic.value = value;
  if (key === 'tag') elements.filterTag.value = value;
  if (key === 'type') elements.filterType.value = value;
  if (key === 'importance') elements.filterImportance.value = value;
  fetchKnowledgeItems();
}

function resetAllFilters() {
  state.activeFilters.q = '';
  state.activeFilters.topic = '';
  state.activeFilters.type = '';
  state.activeFilters.tag = '';
  state.activeFilters.importance = '';
  state.activeFilters.sortBy = 'updated_at';
  state.activeFilters.sortDir = 'desc';

  elements.searchInput.value = '';
  elements.btnClearSearch.style.display = 'none';
  elements.filterTopic.value = '';
  elements.filterType.value = '';
  elements.filterTag.value = '';
  elements.filterImportance.value = '';
  elements.filterSort.value = 'updated_at:desc';

  fetchKnowledgeItems();
}

// ==============================================================================
// 8. Modal & Toast Utilities
// ==============================================================================

function openModal(modalEl) {
  modalEl.classList.add('active');
  modalEl.setAttribute('aria-hidden', 'false');
  document.body.style.overflow = 'hidden';
}

function closeModal(modalEl) {
  modalEl.classList.remove('active');
  modalEl.setAttribute('aria-hidden', 'true');
  document.body.style.overflow = '';
}

function showToast(message, type = 'info') {
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.textContent = message;
  elements.toastContainer.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(8px)';
    toast.style.transition = 'all 200ms ease';
    setTimeout(() => toast.remove(), 200);
  }, 3200);
}

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
