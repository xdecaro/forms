(() => {
  'use strict';

  const ALLOWED_INTENTS = new Set([
    'select',
    'move-beside',
    'move-new-row',
    'resize',
    'duplicate',
    'delete'
  ]);

  class DecaroFormsEditorBuilderAdapter {
    constructor(callbacks = {}) {
      this.callbacks = callbacks;
      this.root = null;
      this.bound = false;
      this.onIntent = this.onIntent.bind(this);
    }

    static isSupportedIntent(intent) {
      return Boolean(intent && ALLOWED_INTENTS.has(String(intent.type || '')));
    }

    static normalizeIntent(raw = {}) {
      const type = String(raw.type || '').trim();
      if (!ALLOWED_INTENTS.has(type)) return null;

      const intent = {type};
      if (raw.fieldKey != null) intent.fieldKey = String(raw.fieldKey);
      if (raw.targetKey != null) intent.targetKey = String(raw.targetKey);
      if (raw.position != null) intent.position = raw.position === 'before' ? 'before' : 'after';
      if (raw.row != null) intent.row = Math.max(1, Number(raw.row) || 1);
      if (raw.width != null) intent.width = Math.max(1, Math.min(100, Number(raw.width) || 100));
      return intent;
    }

    bind(root) {
      if (!(root instanceof Element)) {
        throw new TypeError('Forms Editor Builder adapter requires a root Element.');
      }

      if (this.bound) this.destroy();
      this.root = root;
      this.root.addEventListener('xdecaro:builder:intent', this.onIntent);
      this.bound = true;
      this.emit('ready', {mode: 'host-managed'});
      return this;
    }

    destroy() {
      if (this.root && this.bound) {
        this.root.removeEventListener('xdecaro:builder:intent', this.onIntent);
      }
      this.root = null;
      this.bound = false;
    }

    onIntent(event) {
      const raw = event?.detail?.intent || event?.detail || {};
      const intent = DecaroFormsEditorBuilderAdapter.normalizeIntent(raw);
      if (!intent) {
        this.emit('rejected', {reason: 'unsupported-intent', raw});
        return;
      }

      const result = this.commit(intent);
      if (result === false) {
        this.emit('rejected', {reason: 'host-rejected', intent});
        return;
      }

      this.emit('committed', {intent});
    }

    commit(intent) {
      const cb = this.callbacks;

      switch (intent.type) {
        case 'select':
          return this.call(cb.selectField, intent.fieldKey);

        case 'move-beside':
          if (!intent.fieldKey || !intent.targetKey) return false;
          return this.call(cb.moveBeside, intent.fieldKey, intent.targetKey, intent.position || 'after');

        case 'move-new-row':
          if (!intent.fieldKey || !intent.row) return false;
          return this.call(cb.moveNewRow, intent.fieldKey, intent.row, intent.position || 'after');

        case 'resize':
          if (!intent.fieldKey || intent.width == null) return false;
          return this.call(cb.setWidth, intent.fieldKey, intent.width);

        case 'duplicate':
          if (!intent.fieldKey) return false;
          return this.call(cb.duplicateField, intent.fieldKey);

        case 'delete':
          if (!intent.fieldKey) return false;
          return this.call(cb.deleteField, intent.fieldKey);

        default:
          return false;
      }
    }

    call(fn, ...args) {
      if (typeof fn !== 'function') return false;
      return fn(...args) !== false;
    }

    describeDom(root = this.root) {
      if (!(root instanceof Element)) return [];

      return [...root.querySelectorAll('.df-layout-row')].map((row, rowIndex) => ({
        rowIndex: rowIndex + 1,
        row: Number(row.dataset.row || rowIndex + 1),
        fields: [...row.querySelectorAll('.df-layout-card[data-field-key]')].map((card, colIndex) => ({
          key: String(card.dataset.fieldKey || ''),
          col: colIndex + 1
        })).filter((field) => field.key)
      }));
    }

    emit(name, detail = {}) {
      if (!this.root) return;
      this.root.dispatchEvent(new CustomEvent(`decaroforms:editor-builder:${name}`, {
        bubbles: true,
        detail: {adapter: this, ...detail}
      }));
    }
  }

  window.DecaroFormsEditorBuilderAdapter = DecaroFormsEditorBuilderAdapter;
})();
