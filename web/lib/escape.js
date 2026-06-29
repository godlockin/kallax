// web/lib/escape.js — XSS-safe HTML/text escaping utility
// 治根 FE-001: 取代 innerHTML 拼接, 任何远端/用户数据必须经此函数
// 跟 web/app.js + web/lib/render.js 联合使用
// V310 hotfix U-001 (B-Attack P-004): attribute value sanitization 防 javascript:/on*= 注入
(function (root) {
  'use strict';
  const ESCAPE_MAP = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ESCAPE_MAP[c]; });
  }
  // V310 hotfix U-001: attribute value escape (防 setAttribute("onclick", ...) XSS)
  function escapeAttr(s) {
    return escapeHtml(s);
  }
  // V310 hotfix U-001: URL sanitization (block javascript:/data: schemes)
  function sanitizeUrl(url) {
    if (typeof url !== 'string') return '';
    const trimmed = url.trim().toLowerCase();
    if (trimmed.startsWith('javascript:') || trimmed.startsWith('data:text/html') || trimmed.startsWith('vbscript:')) {
      return 'about:blank';
    }
    return url;
  }
  // Element factory: 替代 innerHTML 拼接, 自动用 textContent 设置纯文本字段
  // V310 hotfix U-001: attribute 值统一走 setAttribute + escapeAttr, 不用直赋值
  // (line 17 旧的 node[k] = attrs[k] 会让 onclick=alert(1) 在某些 attribute 名下执行)
  function el(tag, attrs, text) {
    const node = document.createElement(tag);
    if (attrs) for (const k in attrs) {
      let v = attrs[k];
      // href/src 等 URL 属性走 sanitizeUrl
      if (k === 'href' || k === 'src' || k === 'action' || k === 'formaction') {
        v = sanitizeUrl(v);
      }
      // class 走 className (保留原始 行为); 其他 attribute 走 setAttribute + escapeAttr
      if (k === 'class') {
        node.className = String(v);
      } else if (k === 'style') {
        node.setAttribute('style', String(v));
      } else if (k === 'value' || k === 'id' || k === 'type' || k === 'name' || k === 'placeholder' || k === 'title' || k === 'alt' || k === 'role' || k === 'aria-label') {
        // 已知安全 attribute, 用 setAttribute + escapeAttr 防御
        node.setAttribute(k, escapeAttr(v));
      } else if (k.startsWith('data-') || k.startsWith('aria-')) {
        node.setAttribute(k, escapeAttr(v));
      } else {
        // 其他 attribute (含 user-supplied) 走 setAttribute + escapeAttr, 避免 node[k]= 直赋值
        // 拦截 on*= event handler attribute (强制 strip)
        if (k.toLowerCase().startsWith('on')) {
          // eslint-disable-next-line no-console
          console.warn('[KallaxEscape] dropped event handler attribute:', k);
          continue;
        }
        node.setAttribute(k, escapeAttr(v));
      }
    }
    if (text != null) node.textContent = String(text);
    return node;
  }
  const api = { escapeHtml: escapeHtml, escapeAttr: escapeAttr, sanitizeUrl: sanitizeUrl, el: el };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.KallaxEscape = api;
})(typeof window !== 'undefined' ? window : globalThis);