import React, { useState, useEffect } from "react";

function ProductSelectionStep({
  loading,
  error,
  products,
  apiUrl,
  countryCode,
  onCountryChange,
  onProductSelect,
  onRetry,
}) {
  const [currentStep, setCurrentStep] = useState("type-selection");
  const [selectedProductType, setSelectedProductType] = useState(null);
  const [frameSkuData, setFrameSkuData] = useState(null);
  const [frameSkuLoading, setFrameSkuLoading] = useState(false);
  const [frameSkuError, setFrameSkuError] = useState(null);
  const [selectedOptions, setSelectedOptions] = useState({
    mat_style: "",
    glass_type: "",
    paper_type: "",
    frame_style_colour: "",
  });
  const [searchResults, setSearchResults] = useState(null);
  const [searchLoading, setSearchLoading] = useState(false);
  const [searchError, setSearchError] = useState(null);
  const [selectedCountry, setSelectedCountry] = useState(countryCode || "NZ");

  // Supported countries
  const supportedCountries = [
    { code: "NZ", name: "New Zealand", currency: "NZD" },
    { code: "AU", name: "Australia", currency: "AUD" },
  ];

  // Product type configurations
  const productTypes = [
    {
      id: "matted",
      label: "Matted",
      icon: "🖼️", // Placeholder - will be replaced with proper icon
      endpoint: "matted.json",
    },
    {
      id: "unmatted",
      label: "Unmatted",
      icon: "🖼️", // Placeholder - will be replaced with proper icon
      endpoint: "unmatted.json",
    },
    {
      id: "canvas",
      label: "Canvas",
      icon: "🎨", // Placeholder - will be replaced with proper icon
      endpoint: "canvas.json",
    },
    {
      id: "print-only",
      label: "Print Only",
      icon: "📄", // Placeholder - will be replaced with proper icon
      endpoint: "unframed.json",
    },
  ];

  // Get the base API URL based on selected country
  const getApiUrl = () => {
    // Always use selectedCountry to determine URL
    // This allows users to override the order's default country if needed
    const countryUrls = {
      NZ: "http://dev.framefox.co.nz:3001/api",
      AU: "http://dev.framefox.com.au:3001/api",
    };
    return countryUrls[selectedCountry] || countryUrls["NZ"];
  };

  // Fetch frame SKU data when product type is selected
  const fetchFrameSkuData = async (productType) => {
    setFrameSkuLoading(true);
    setFrameSkuError(null);

    try {
      const endpoint = productTypes.find(
        (type) => type.id === productType
      )?.endpoint;
      const baseUrl = getApiUrl();
      const response = await fetch(
        `${baseUrl}/shopify-customers/7315072254051/frame_skus/${endpoint}`
      );

      if (!response.ok) {
        throw new Error(
          `Failed to fetch frame SKU data: ${response.statusText}`
        );
      }

      const data = await response.json();
      setFrameSkuData(data);
      setCurrentStep("option-selection");
    } catch (err) {
      setFrameSkuError(err.message);
    } finally {
      setFrameSkuLoading(false);
    }
  };

  const handleProductTypeSelect = (productType) => {
    setSelectedProductType(productType);
    fetchFrameSkuData(productType);
  };

  // Search frame SKUs based on selected options
  const searchFrameSkus = async (options) => {
    setSearchLoading(true);
    setSearchError(null);

    try {
      // Build query parameters, only including non-empty values
      const params = new URLSearchParams();

      if (options.paper_type) {
        params.append("paper_type_id", options.paper_type);
      }
      if (options.glass_type) {
        params.append("glass_type_id", options.glass_type);
      }
      if (options.mat_style) {
        params.append("mat_style_id", options.mat_style);
      }
      if (options.frame_style_colour) {
        params.append("frame_style_colour_id", options.frame_style_colour);
      }

      const baseUrl = getApiUrl();
      const url = `${baseUrl}/shopify-customers/7315072254051/frame_skus.json${
        params.toString() ? "?" + params.toString() : ""
      }`;
      const response = await fetch(url);

      if (!response.ok) {
        throw new Error(`Failed to search frame SKUs: ${response.statusText}`);
      }

      const data = await response.json();
      // Extract the frame_skus array from the response
      setSearchResults(data.frame_skus || []);
    } catch (err) {
      setSearchError(err.message);
    } finally {
      setSearchLoading(false);
    }
  };

  const handleOptionChange = (optionType, value) => {
    setSelectedOptions((prev) => ({
      ...prev,
      [optionType]: value,
    }));
  };

  const handleSearch = () => {
    searchFrameSkus(selectedOptions);
  };

  // Auto-run search with first options when frameSkuData is loaded
  useEffect(() => {
    if (frameSkuData && !frameSkuLoading && !frameSkuError) {
      // Build auto-selected options using first item from each available select field
      const autoSelectedOptions = {};

      if (frameSkuData.mat_styles && frameSkuData.mat_styles.length > 0) {
        autoSelectedOptions.mat_style = frameSkuData.mat_styles[0].id;
      }

      if (frameSkuData.glass_types && frameSkuData.glass_types.length > 0) {
        autoSelectedOptions.glass_type = frameSkuData.glass_types[0].id;
      }

      if (frameSkuData.paper_types && frameSkuData.paper_types.length > 0) {
        autoSelectedOptions.paper_type = frameSkuData.paper_types[0].id;
      }

      if (
        frameSkuData.frame_style_colours &&
        frameSkuData.frame_style_colours.length > 0
      ) {
        autoSelectedOptions.frame_style_colour =
          frameSkuData.frame_style_colours[0].id;
      }

      // Update selected options state
      setSelectedOptions((prev) => ({
        ...prev,
        ...autoSelectedOptions,
      }));

      // Auto-run search with the first options
      searchFrameSkus(autoSelectedOptions);
    }
  }, [frameSkuData, frameSkuLoading, frameSkuError]);

  const handleBackToTypeSelection = () => {
    setCurrentStep("type-selection");
    setSelectedProductType(null);
    setFrameSkuData(null);
    setFrameSkuError(null);
    setSearchResults(null);
    setSearchError(null);
    setSelectedOptions({
      mat_style: "",
      glass_type: "",
      paper_type: "",
      frame_style_colour: "",
    });
  };

  // Reset product selection when country changes
  useEffect(() => {
    // Only reset if user has already made selections
    if (selectedProductType || frameSkuData) {
      handleBackToTypeSelection();
    }
  }, [selectedCountry]);

  // Helper function to format cents to dollars
  const formatCentsToPrice = (cents) => {
    if (!cents && cents !== 0) return "N/A";
    return `$${(cents / 100).toFixed(2)}`;
  };

  // Render product type selection step
  if (currentStep === "type-selection") {
    return (
      <div className="py-8">
        {/* Country Selector */}
        <div className="mb-8 max-w-md mx-auto">
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Shipping Country
          </label>
          <select
            value={selectedCountry}
            onChange={(e) => {
              const newCountry = e.target.value;
              setSelectedCountry(newCountry);
              if (onCountryChange) {
                onCountryChange(newCountry);
              }
            }}
            className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-slate-950 focus:border-slate-950 transition-colors"
          >
            {supportedCountries.map((country) => (
              <option key={country.code} value={country.code}>
                {country.name} ({country.currency})
              </option>
            ))}
          </select>
          <p className="mt-2 text-sm text-gray-500">
            Frame SKUs will be loaded from the{" "}
            {supportedCountries.find((c) => c.code === selectedCountry)?.name}{" "}
            production system
          </p>
        </div>

        <h3 className="text-lg font-medium text-gray-900 mb-6 text-center">
          Select Product Type
        </h3>
        <div className="grid grid-cols-2 gap-6 max-w-2xl mx-auto">
          {productTypes.map((type) => (
            <button
              key={type.id}
              onClick={() => handleProductTypeSelect(type.id)}
              className="flex flex-col items-center justify-center p-8 border-2 border-gray-200 rounded-lg hover:border-slate-900 hover:bg-gray-50 transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
            >
              <div className="text-4xl mb-4">{type.icon}</div>
              <span className="text-lg font-medium text-gray-900">
                {type.label}
              </span>
            </button>
          ))}
        </div>
      </div>
    );
  }

  // Render option selection step
  if (currentStep === "option-selection") {
    return (
      <div className="pb-8">
        <div className="flex items-center justify-between mb-6">
          <button
            onClick={handleBackToTypeSelection}
            className="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950"
          >
            <svg
              className="w-4 h-4 mr-2"
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
            Back
          </button>
          <h3 className="text-lg font-medium text-gray-900">
            Find a{" "}
            {
              productTypes.find((type) => type.id === selectedProductType)
                ?.label
            }{" "}
            product
          </h3>
          <div></div> {/* Spacer for flexbox */}
        </div>

        {frameSkuLoading && (
          <div className="flex items-center justify-center py-8">
            <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
            <span className="ml-3 text-gray-600">Loading options...</span>
          </div>
        )}

        {frameSkuError && (
          <div className="text-center py-8">
            <div className="text-red-600 mb-2">{frameSkuError}</div>
            <button
              onClick={() => fetchFrameSkuData(selectedProductType)}
              className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
            >
              Try Again
            </button>
          </div>
        )}

        {frameSkuData && !frameSkuLoading && !frameSkuError && (
          <div className="grid grid-cols-1 md:grid-cols-5 gap-6">
            {/* Mat Styles */}
            {frameSkuData.mat_styles && frameSkuData.mat_styles.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Mat Style
                </label>
                <select
                  value={selectedOptions.mat_style}
                  onChange={(e) =>
                    handleOptionChange("mat_style", e.target.value)
                  }
                  className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                >
                  <option value="">Select a mat style...</option>
                  {frameSkuData.mat_styles.map((style) => (
                    <option key={style.id} value={style.id}>
                      {style.title}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {/* Glass Types */}
            {frameSkuData.glass_types &&
              frameSkuData.glass_types.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Glass Type
                  </label>
                  <select
                    value={selectedOptions.glass_type}
                    onChange={(e) =>
                      handleOptionChange("glass_type", e.target.value)
                    }
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                  >
                    <option value="">Select a glass type...</option>
                    {frameSkuData.glass_types.map((type) => (
                      <option key={type.id} value={type.id}>
                        {type.title}
                      </option>
                    ))}
                  </select>
                </div>
              )}

            {/* Paper Types */}
            {frameSkuData.paper_types &&
              frameSkuData.paper_types.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Paper Type
                  </label>
                  <select
                    value={selectedOptions.paper_type}
                    onChange={(e) =>
                      handleOptionChange("paper_type", e.target.value)
                    }
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                  >
                    <option value="">Select a paper type...</option>
                    {frameSkuData.paper_types.map((type) => (
                      <option key={type.id} value={type.id}>
                        {type.title}
                      </option>
                    ))}
                  </select>
                </div>
              )}

            {/* Frame Style Colours */}
            {frameSkuData.frame_style_colours &&
              frameSkuData.frame_style_colours.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Frame Style
                  </label>
                  <select
                    value={selectedOptions.frame_style_colour}
                    onChange={(e) =>
                      handleOptionChange("frame_style_colour", e.target.value)
                    }
                    className="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950"
                  >
                    <option value="">Select a frame style colour...</option>
                    {frameSkuData.frame_style_colours.map((colour) => (
                      <option key={colour.id} value={colour.id}>
                        {colour.title}
                      </option>
                    ))}
                  </select>
                </div>
              )}

            {/* Search Button */}
            <div className="flex flex-col justify-end">
              <button
                onClick={handleSearch}
                disabled={searchLoading}
                className="w-full px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {searchLoading ? (
                  <>
                    <i className="fa-solid fa-spinner-third fa-spin mr-2"></i>
                    Searching...
                  </>
                ) : (
                  <>
                    <svg
                      className="w-4 h-4 mr-2 inline"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth="2"
                        d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                      />
                    </svg>
                    Search
                  </>
                )}
              </button>
            </div>
          </div>
        )}

        {/* Search Results Section */}
        {(searchLoading || searchError || searchResults) && (
          <div className="mt-8">
            <h4 className="text-md font-medium text-gray-900 mb-4">
              Search Results
            </h4>

            {searchLoading && (
              <div className="flex items-center justify-center py-8">
                <i className="fa-solid fa-spinner-third fa-spin text-blue-600 text-2xl"></i>
                <span className="ml-3 text-gray-600">
                  Searching frame SKUs...
                </span>
              </div>
            )}

            {searchError && (
              <div className="text-center py-8">
                <div className="text-red-600 mb-2">{searchError}</div>
                <button
                  onClick={() => searchFrameSkus(selectedOptions)}
                  className="px-4 py-2 bg-slate-900 text-slate-50 hover:bg-slate-800 rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
                >
                  Try Again
                </button>
              </div>
            )}

            {searchResults && !searchLoading && !searchError && (
              <div>
                {searchResults.length === 0 ? (
                  <div className="text-center py-8 text-gray-500">
                    No frame SKUs found for the selected options
                  </div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="min-w-full divide-y divide-gray-200">
                      <thead className="bg-gray-50">
                        <tr>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Preview
                          </th>
                          <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Size
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
                        {searchResults.map((sku) => (
                          <tr key={sku.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 whitespace-nowrap">
                              {sku.preview_image ? (
                                <div className="h-24 w-24">
                                  <img
                                    src={sku.preview_image}
                                    alt={sku.title}
                                    className="object-contain shadow-md"
                                  />
                                </div>
                              ) : (
                                <div className="h-16 w-16 bg-gray-200 rounded-md flex items-center justify-center">
                                  <svg
                                    className="h-8 w-8 text-gray-400"
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
                            <td className="px-6 py-4 text-sm text-gray-900">
                              {sku.title || "No size"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.frame_style || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.mat_style || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.glass_type || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              {sku.paper_type || "-"}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                              {formatCentsToPrice(sku.cost_cents)}
                            </td>
                            <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                              <button
                                onClick={() => onProductSelect(sku)}
                                className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-slate-50 bg-slate-900 hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-950 transition-colors"
                              >
                                Select
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    );
  }
}

export default ProductSelectionStep;
