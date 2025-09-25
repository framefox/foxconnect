import React, { useState, useEffect } from "react";
import Modal from "react-modal";
import axios from "axios";

// Make sure to bind modal to your appElement (https://reactcommunity.org/react-modal/accessibility/)
Modal.setAppElement("body");

const customStyles = {
  content: {
    top: "50%",
    left: "50%",
    right: "auto",
    bottom: "auto",
    marginRight: "-50%",
    transform: "translate(-50%, -50%)",
    width: "80%",
    height: "80vh",
    padding: "0",
    border: "none",
    borderRadius: "12px",
    boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)",
  },
  overlay: {
    backgroundColor: "rgba(0, 0, 0, 0.5)",
    zIndex: 1000,
  },
};

function ProductSelectModal({ isOpen, onRequestClose, onProductSelect }) {
  const [step, setStep] = useState(1); // 1: Select Product, 2: Select Artwork
  const [products, setProducts] = useState([]);
  const [artworks, setArtworks] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [loading, setLoading] = useState(false);
  const [artworkLoading, setArtworkLoading] = useState(false);
  const [error, setError] = useState(null);
  const [artworkError, setArtworkError] = useState(null);

  useEffect(() => {
    if (isOpen) {
      // Reset to step 1 when modal opens
      setStep(1);
      setSelectedProduct(null);
      setArtworks([]);
      setError(null);
      setArtworkError(null);
      fetchProducts();
    }
  }, [isOpen]);

  const fetchProducts = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await axios.get(
        "https://shop.framefox.co.nz/api/shopify-customers/7315072254051/frame_skus.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
      );
      setProducts(response.data.frame_skus);
    } catch (err) {
      setError("Failed to load products. Please try again.");
      console.error("Error fetching products:", err);
    } finally {
      setLoading(false);
    }
  };

  const fetchArtworks = async () => {
    setArtworkLoading(true);
    setArtworkError(null);
    try {
      const response = await axios.get(
        "https://shop.framefox.co.nz/api/shopify-customers/7315072254051/images.json?auth=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3"
      );
      setArtworks(response.data.images);
    } catch (err) {
      setArtworkError("Failed to load artworks. Please try again.");
      console.error("Error fetching artworks:", err);
    } finally {
      setArtworkLoading(false);
    }
  };

  const handleProductSelect = (product) => {
    setSelectedProduct(product);
    setStep(2);
    fetchArtworks();
  };

  const handleArtworkSelect = (artwork) => {
    if (onProductSelect) {
      onProductSelect({
        product: selectedProduct,
        artwork: artwork,
      });
    }
    onRequestClose();
  };

  const handleBackToProducts = () => {
    setStep(1);
    setArtworkError(null);
  };

  return (
    <Modal
      isOpen={isOpen}
      onRequestClose={onRequestClose}
      style={customStyles}
      contentLabel="Choose Product"
    >
      <div className="bg-white rounded-lg">
        {/* Modal Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <div className="flex items-center space-x-4">
            {step === 2 && (
              <button
                onClick={handleBackToProducts}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <svg
                  className="w-6 h-6"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M15 19l-7-7 7-7"
                  />
                </svg>
              </button>
            )}
            <h2 className="text-xl font-semibold text-gray-900">
              {step === 1 ? "Choose Product" : "Select an Artwork"}
            </h2>
          </div>
          {step === 1 && selectedProduct && (
            <div className="flex items-center space-x-3 text-sm text-gray-600">
              <span>Selected: {selectedProduct.code}</span>
            </div>
          )}
          <button
            onClick={onRequestClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <svg
              className="w-6 h-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        {/* Modal Content */}
        <div
          className="p-6"
          style={{ maxHeight: "calc(80vh - 140px)", overflowY: "auto" }}
        >
          {/* Step 1: Product Selection */}
          {step === 1 && (
            <>
              {loading && (
                <div className="flex items-center justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span className="ml-3 text-gray-600">
                    Loading products...
                  </span>
                </div>
              )}

              {error && (
                <div className="text-center py-8">
                  <div className="text-red-600 mb-2">{error}</div>
                  <button
                    onClick={fetchProducts}
                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                  >
                    Try Again
                  </button>
                </div>
              )}

              {!loading && !error && products.length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  No products available
                </div>
              )}

              {!loading && !error && products.length > 0 && (
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Image
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Code
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Description
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Frame Style
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Mat Style
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Glass Type
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Paper Type
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Price
                        </th>
                        <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                          Action
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-gray-200">
                      {products.map((product) => (
                        <tr key={product.id} className="hover:bg-gray-50">
                          <td className="px-6 py-4 whitespace-nowrap">
                            {product.preview_image ? (
                              <div className="h-24 w-24">
                                <img
                                  src={product.preview_image}
                                  alt={product.description}
                                  className="object-contain shadow-md"
                                />
                              </div>
                            ) : (
                              <div className="h-12 w-12 bg-gray-200 rounded-md flex items-center justify-center">
                                <svg
                                  className="h-6 w-6 text-gray-400"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    strokeWidth="2"
                                    d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
                                  />
                                </svg>
                              </div>
                            )}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            {product.code}
                          </td>
                          <td className="px-6 py-4 text-sm text-gray-900 max-w-xs truncate">
                            {product.description}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {product.frame_style || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {product.mat_style || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {product.glass_type || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {product.paper_type || "-"}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                            ${product.price}
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                            <button
                              onClick={() => handleProductSelect(product)}
                              className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                            >
                              SELECT
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}

          {/* Step 2: Artwork Selection */}
          {step === 2 && (
            <>
              {selectedProduct && (
                <div className="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <div className="flex items-center space-x-4">
                    {selectedProduct.preview_image && (
                      <img
                        src={selectedProduct.preview_image}
                        alt={selectedProduct.description}
                        className="h-16 w-16 object-contain rounded-md"
                      />
                    )}
                    <div>
                      <h3 className="text-lg font-medium text-gray-900">
                        {selectedProduct.code}
                      </h3>
                      <p className="text-sm text-gray-600">
                        {selectedProduct.description}
                      </p>
                      <p className="text-sm font-medium text-blue-600">
                        ${selectedProduct.price}
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {artworkLoading && (
                <div className="flex items-center justify-center py-8">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span className="ml-3 text-gray-600">
                    Loading artworks...
                  </span>
                </div>
              )}

              {artworkError && (
                <div className="text-center py-8">
                  <div className="text-red-600 mb-2">{artworkError}</div>
                  <button
                    onClick={fetchArtworks}
                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors"
                  >
                    Try Again
                  </button>
                </div>
              )}

              {!artworkLoading && !artworkError && artworks.length === 0 && (
                <div className="text-center py-8 text-gray-500">
                  No artworks available
                </div>
              )}

              {!artworkLoading && !artworkError && artworks.length > 0 && (
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  {artworks.map((artwork) => (
                    <div
                      key={artwork.id}
                      className="group relative bg-white border border-gray-200 rounded-lg overflow-hidden cursor-pointer p-3"
                      onClick={() => handleArtworkSelect(artwork)}
                    >
                      <div className="flex">
                        {/* Image section */}
                        <div className="w-24 h-24 flex-shrink-0 bg-gray-50 flex items-center justify-center rounded-l-lg">
                          <img
                            src={artwork.url}
                            alt={artwork.filename}
                            className="w-full h-full object-contain"
                          />
                        </div>

                        {/* Details section */}
                        <div className="flex-1 p-4">
                          <div className="space-y-3">
                            <div>
                              <p className="text-sm font-semibold text-slate-900 truncate">
                                {artwork.filename}
                              </p>
                              <p className="text-xs text-slate-500 mt-1">
                                ID: {artwork.id} | Key: {artwork.key}
                              </p>
                              <span className="text-slate-600 text-xs">
                                {artwork.width} × {artwork.height}px
                              </span>
                            </div>
                          </div>
                        </div>

                        {/* Select button */}
                        <div className="p-4 flex items-center">
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleArtworkSelect(artwork);
                            }}
                            className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
                          >
                            Select
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </Modal>
  );
}

export default ProductSelectModal;
