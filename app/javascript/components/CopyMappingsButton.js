import React, { useState, useEffect } from "react";
import CopyMappingsModal from "./CopyMappingsModal";

function CopyMappingsButton({ product, candidatesUrl, copyUrl, csrfToken }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  useEffect(() => {
    const link = document.querySelector("[data-copy-mappings-link]");

    if (link) {
      const handleClick = (e) => {
        e.preventDefault();
        setIsModalOpen(true);
      };

      link.addEventListener("click", handleClick);

      return () => {
        link.removeEventListener("click", handleClick);
      };
    }
  }, []);

  return (
    <CopyMappingsModal
      isOpen={isModalOpen}
      onClose={() => setIsModalOpen(false)}
      product={product}
      candidatesUrl={candidatesUrl}
      copyUrl={copyUrl}
      csrfToken={csrfToken}
    />
  );
}

export default CopyMappingsButton;
