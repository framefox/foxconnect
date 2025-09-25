import React from "react";
import { createRoot } from "react-dom/client";

function decodeHtmlEntities(str) {
  const el = document.createElement("textarea");
  el.innerHTML = str;
  return el.value;
}

function parseProps(raw) {
  if (!raw) return {};
  // Normalize spacing
  let s = raw.trim();
  // Decode HTML entities like &quot;
  s = decodeHtmlEntities(s);
  // If it looks like already-escaped JSON attributes (e.g. {\"key\":\"val\"}), unescape backslashes
  if (/^\{\\"/.test(s)) {
    s = s.replace(/\\(["\\/bfnrt])/g, "$1");
  }
  try {
    return JSON.parse(s);
  } catch (_) {
    try {
      const coerced = s
        .replace(/'([^']*)'\s*:/g, '"$1":')
        .replace(/:\s*'([^']*)'/g, ':"$1"');
      return JSON.parse(coerced);
    } catch (err) {
      console.error("Failed to parse data-react-props:", raw, err);
      return {};
    }
  }
}

// Auto-mount components declared via data-react-component
// Example: <div data-react-component="Sidebar" data-react-props='{"foo": "bar"}'></div>
document.addEventListener("DOMContentLoaded", () => {
  const targets = document.querySelectorAll("[data-react-component]");
  targets.forEach(async (el) => {
    const componentName = el.dataset.reactComponent;
    const props = parseProps(el.getAttribute("data-react-props"));

    try {
      console.debug(`Mounting ${componentName} with props`, props);
      // Dynamically import from app/javascript/components/<Name>.js
      const module = await import(`./components/${componentName}.js`);
      const Component = module.default;
      const root = createRoot(el);
      root.render(React.createElement(Component, props));
    } catch (error) {
      console.error(`Failed to mount component '${componentName}':`, error);
    }
  });
});
