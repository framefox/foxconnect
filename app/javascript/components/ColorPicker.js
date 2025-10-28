import React, { useState, useEffect } from "react";

const COLOR_SWATCHES = [
  { name: "White", value: "ffffff" },
  { name: "Light Grey", value: "f4f4f4" },
  { name: "Medium Grey", value: "d4d4d4" },
  { name: "Dark Grey", value: "a3a3a3" },
];

function ColorPicker({ name, initialValue = "f4f4f4", onChange }) {
  const [selectedColor, setSelectedColor] = useState(initialValue);
  const [hexInput, setHexInput] = useState(initialValue);

  useEffect(() => {
    setSelectedColor(initialValue);
    setHexInput(initialValue);
  }, [initialValue]);

  const handleSwatchClick = (color) => {
    const cleanColor = color.replace("#", "");
    setSelectedColor(cleanColor);
    setHexInput(cleanColor);
    if (onChange) {
      onChange(cleanColor);
    }
  };

  const handleHexInputChange = (e) => {
    let value = e.target.value.replace("#", "");
    setHexInput(value);
  };

  const handleHexInputBlur = () => {
    // Validate hex color
    const hexRegex = /^[0-9A-Fa-f]{6}$/;
    if (hexRegex.test(hexInput)) {
      setSelectedColor(hexInput);
      if (onChange) {
        onChange(hexInput);
      }
    } else {
      // Reset to last valid color
      setHexInput(selectedColor);
    }
  };

  const handleHexInputKeyPress = (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleHexInputBlur();
    }
  };

  return (
    <div className="space-y-4">
      {/* Color Swatches */}
      <div className="flex flex-wrap gap-3">
        {COLOR_SWATCHES.map((swatch) => (
          <button
            key={swatch.value}
            type="button"
            onClick={() => handleSwatchClick(swatch.value)}
            className={`group relative flex flex-col items-center space-y-2 transition-all ${
              selectedColor.toLowerCase() === swatch.value.toLowerCase()
                ? "scale-105"
                : "hover:scale-105"
            }`}
            title={swatch.name}
          >
            <div
              className={`w-12 h-12 rounded-lg border-2 transition-all ${
                selectedColor.toLowerCase() === swatch.value.toLowerCase()
                  ? "border-slate-900 shadow-md"
                  : "border-slate-300 group-hover:border-slate-500"
              }`}
              style={{ backgroundColor: `#${swatch.value}` }}
            >
              {selectedColor.toLowerCase() === swatch.value.toLowerCase() && (
                <div className="flex items-center justify-center h-full">
                  <svg
                    className="w-5 h-5 text-slate-900"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth="3"
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                </div>
              )}
            </div>
            <span className="text-xs text-slate-600">{swatch.name}</span>
          </button>
        ))}
      </div>

      {/* Hex Input */}
      <div className="space-y-2">
        <label
          htmlFor="hex-input"
          className="block text-sm font-medium text-slate-700"
        >
          Hex Color
        </label>
        <div className="flex items-center space-x-2">
          <div className="flex-1 relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <span className="text-slate-500 text-sm">#</span>
            </div>
            <input
              id="hex-input"
              type="text"
              value={hexInput}
              onChange={handleHexInputChange}
              onBlur={handleHexInputBlur}
              onKeyPress={handleHexInputKeyPress}
              maxLength={6}
              placeholder="f4f4f4"
              className="block w-full pl-8 pr-3 py-2 border border-slate-300 rounded-md shadow-sm focus:border-slate-900 focus:ring-2 focus:ring-slate-200 focus:ring-opacity-50 text-slate-900 text-sm font-mono uppercase"
            />
          </div>
          <div
            className="w-10 h-10 rounded-md border-2 border-slate-300"
            style={{ backgroundColor: `#${selectedColor}` }}
          />
        </div>
        <p className="text-xs text-slate-500">
          Enter a 6-digit hex color code without the # symbol
        </p>
      </div>

      {/* Hidden input for form submission */}
      <input type="hidden" name={name} value={selectedColor} />
    </div>
  );
}

export default ColorPicker;
