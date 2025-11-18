import React, { useState, useEffect } from "react";
import SyncVariantMockupsModal from "./SyncVariantMockupsModal";

function SyncVariantMockupsButton({ variantMappingsCount, syncUrl, storePlatform }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    // Find the sync variant mockups link and intercept clicks
    const syncLink = document.querySelector('[data-sync-variant-mockups-link]');
    
    if (syncLink) {
      const handleClick = (e) => {
        e.preventDefault();
        setIsModalOpen(true);
      };

      syncLink.addEventListener('click', handleClick);

      return () => {
        syncLink.removeEventListener('click', handleClick);
      };
    }
  }, []);

  return (
    <SyncVariantMockupsModal
      isOpen={isModalOpen}
      onClose={() => setIsModalOpen(false)}
      variantMappingsCount={variantMappingsCount}
      syncUrl={syncUrl}
      storePlatform={storePlatform}
    />
  );
}

export default SyncVariantMockupsButton;

