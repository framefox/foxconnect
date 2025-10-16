import React, { useState, useEffect } from "react";

/**
 * SvgIcon Component
 *
 * A React component that mimics the Rails svg_icon helper functionality.
 * Fetches SVG files from the Rails asset pipeline.
 *
 * Usage:
 *   <SvgIcon name="OrderFulfilledIcon" className="w-5 h-5 text-blue-600" />
 *   <SvgIcon name="XCircleIcon" className="w-4 h-4" aria-label="Close" />
 *
 * Props:
 *   - name: (required) The name of the SVG file (without .svg extension)
 *   - className: CSS classes to apply to the SVG
 *   - Any other HTML attributes (aria-label, role, etc.) using camelCase
 */
const SvgIcon = ({ name, className = "", ...otherProps }) => {
  const [svgContent, setSvgContent] = useState("");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    const loadIcon = async () => {
      if (!name) {
        setIsLoading(false);
        return;
      }

      setIsLoading(true);
      setError(false);

      try {
        // Fetch SVG from Rails icons endpoint
        const response = await fetch(`/icons/${name}`);

        if (!response.ok) {
          throw new Error(`Failed to load icon: ${name}`);
        }

        let svgText = await response.text();

        // Process SVG to add currentColor and classes (mimics Rails helper)
        svgText = processSvgContent(svgText, className, otherProps);

        setSvgContent(svgText);
      } catch (err) {
        console.error(`Error loading SVG icon "${name}":`, err);
        setError(true);
      } finally {
        setIsLoading(false);
      }
    };

    loadIcon();
  }, [name, className, JSON.stringify(otherProps)]);

  if (isLoading) {
    return null; // Or return a placeholder/skeleton if preferred
  }

  if (error || !svgContent) {
    if (process.env.NODE_ENV !== "production") {
      console.warn(`SVG icon "${name}" could not be loaded`);
    }
    return null;
  }

  return <span dangerouslySetInnerHTML={{ __html: svgContent }} />;
};

/**
 * Process SVG content to add currentColor and attributes
 * Mimics the Rails svg_icon helper behavior
 */
const processSvgContent = (svgContent, className, otherProps) => {
  let processed = svgContent;

  // Ensure SVG inherits text color by setting fill and stroke to currentColor
  processed = processed.replace(/fill="(?!none)[^"]*"/g, 'fill="currentColor"');
  processed = processed.replace(
    /stroke="(?!none)[^"]*"/g,
    'stroke="currentColor"'
  );

  // Add fill="currentColor" if no fill attribute exists
  if (!processed.match(/fill=/)) {
    processed = processed.replace(/<svg/, '<svg fill="currentColor"');
  }

  // Build all attributes to add
  const attributesToAdd = [];

  // Add/modify class attribute
  if (className) {
    const classMatch = processed.match(/<svg[^>]*\sclass="([^"]*)"/);
    if (classMatch) {
      // Replace existing class
      const existingClasses = classMatch[1];
      processed = processed.replace(
        /(<svg[^>]*\s)class="[^"]*"/,
        `$1class="${existingClasses} ${className}"`
      );
    } else {
      attributesToAdd.push(`class="${className}"`);
    }
  }

  // Add additional attributes (convert camelCase to kebab-case)
  Object.entries(otherProps).forEach(([key, value]) => {
    const attrName = key.replace(/([A-Z])/g, "-$1").toLowerCase();
    attributesToAdd.push(`${attrName}="${value}"`);
  });

  // Add all new attributes at once
  if (attributesToAdd.length > 0) {
    processed = processed.replace(/<svg/, `<svg ${attributesToAdd.join(" ")}`);
  }

  return processed;
};

export default SvgIcon;
