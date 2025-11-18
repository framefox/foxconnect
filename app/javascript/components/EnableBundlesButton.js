import React, { useState, useEffect } from "react";
import EnableBundlesModal from "./EnableBundlesModal";

function EnableBundlesButton({ productTitle, toggleUrl, bundlesEnabled }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    // Find the toggle bundles link and intercept clicks
    const toggleLink = document.querySelector('[data-toggle-bundles-link]');
    
    if (toggleLink) {
      const handleClick = (e) => {
        // Only show modal when enabling (not when disabling)
        if (!bundlesEnabled) {
          e.preventDefault();
          setIsModalOpen(true);
        }
        // If disabling, let the default link behavior work
      };

      toggleLink.addEventListener('click', handleClick);

      return () => {
        toggleLink.removeEventListener('click', handleClick);
      };
    }
  }, [bundlesEnabled]);

  return (
    <EnableBundlesModal
      isOpen={isModalOpen}
      onClose={() => setIsModalOpen(false)}
      productTitle={productTitle}
      toggleUrl={toggleUrl}
    />
  );
}

export default EnableBundlesButton;

