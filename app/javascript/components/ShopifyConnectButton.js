import React, { useState } from "react";
import ShopifyConnectModal from "./ShopifyConnectModal";

function ShopifyConnectButton({ connectUrl, buttonText, buttonClass }) {
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <>
      <button onClick={() => setIsModalOpen(true)} className={buttonClass}>
        {buttonText}
      </button>
      <ShopifyConnectModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        connectUrl={connectUrl}
      />
    </>
  );
}

export default ShopifyConnectButton;
