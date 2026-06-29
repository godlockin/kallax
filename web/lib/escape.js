// web/lib/escape.js — XSS-safe HTML/text escaping utility
// 治根 FE-001: 取代 innerHTML 拼接, 任何远端/用户数据必须经此函数
// 跟 web/app.js + web/lib/render.js 联合使用
(function (root) {
  'use strict';
  const ESCAPE_MAP = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return ESCAPE_MAP[c]; });
  }
  // Element factory: 替代 innerHTML 拼接, 自动用 textContent 设置纯文本字段
  function el(tag, attrs, text) {
    const node = document.createElement(tag);
    if (attrs) for (const k in attrs) {
      if (k === 'class') node.className = attrs[k];
      else if (k === 'style') node.setAttribute('style', attrs[k]);
      else if (k.startsWith('data-')) node.setAttribute(k, attrs[k]);
      else node[k] = attrs[k];
    }
    if (text != null) node.textContent = String(text);
    return node;
  }
  const api = { escapeHtml: escapeHtml, el: el };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.KallaxEscape = api;
})(typeof window !== 'undefined' ? window : globalThis);