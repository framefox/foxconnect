import React, { useState, useEffect } from "react";
import axios from "axios";

function BorderMappingsManager({ storeUid, borderMappings: initialMappings, createUrl, deleteUrlBase }) {
  const [mappings, setMappings] = useState(initialMappings || []);
  const [paperTypes, setPaperTypes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);
  const [selectedPaperTypeId, setSelectedPaperTypeId] = useState("");
  const [borderWidthMm, setBorderWidthMm] = useState("");

  const csrfToken = document
    .querySelector('meta[name="csrf-token"]')
    ?.getAttribute("content");

  useEffect(() => {
    fetchPaperTypes();
  }, []);

  const fetchPaperTypes = async () => {
    setLoading(true);
    try {
      const baseApiUrl = window.FramefoxConfig?.apiUrl;
      const apiAuthToken = window.FramefoxConfig?.apiAuthToken;

      if (!baseApiUrl) {
        setError("Framefox API configuration not available. Please refresh the page.");
        setLoading(false);
        return;
      }

      const addAuth = (url) => {
        if (!apiAuthToken) return url;
        const sep = url.includes("?") ? "&" : "?";
        return `${url}${sep}auth=${apiAuthToken}`;
      };

      // Paper types are returned by the product-type-specific endpoints,
      // not the generic /frame_skus.json. Fetch all product types in
      // parallel and merge the unique paper types.
      const endpoints = ["matted.json", "unmatted.json", "canvas.json", "unframed.json"];
      const responses = await Promise.allSettled(
        endpoints.map((ep) =>
          fetch(addAuth(`${baseApiUrl}/frame_skus/${ep}`)).then((r) => r.json())
        )
      );

      const seen = new Set();
      const allPaperTypes = [];
      for (const result of responses) {
        if (result.status !== "fulfilled") continue;
        for (const pt of result.value.paper_types || []) {
          if (!seen.has(pt.id)) {
            seen.add(pt.id);
            allPaperTypes.push(pt);
          }
        }
      }

      allPaperTypes.sort((a, b) => (a.title || "").localeCompare(b.title || ""));
      setPaperTypes(allPaperTypes);
    } catch (err) {
      console.error("Error fetching paper types:", err);
      setError("Failed to load paper types from the Framefox API.");
    } finally {
      setLoading(false);
    }
  };

  const availablePaperTypes = paperTypes.filter(
    (pt) => !mappings.some((m) => m.paper_type_id === pt.id)
  );

  const handleAdd = async (e) => {
    e.preventDefault();

    if (!selectedPaperTypeId || !borderWidthMm) return;

    const paperType = paperTypes.find(
      (pt) => pt.id === parseInt(selectedPaperTypeId, 10)
    );
    if (!paperType) return;

    setSaving(true);
    setError(null);

    try {
      const response = await axios.post(
        createUrl,
        {
          border_mapping: {
            paper_type_id: paperType.id,
            paper_type_name: paperType.title,
            border_width_mm: parseInt(borderWidthMm, 10),
          },
        },
        {
          headers: {
            "Content-Type": "application/json",
            "X-Requested-With": "XMLHttpRequest",
            "X-CSRF-Token": csrfToken,
          },
        }
      );

      setMappings([...mappings, response.data]);
      setSelectedPaperTypeId("");
      setBorderWidthMm("");
    } catch (err) {
      if (err.response?.data?.errors) {
        setError(err.response.data.errors.join(", "));
      } else {
        setError("Failed to save border mapping. Please try again.");
      }
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id) => {
    if (!confirm("Remove this border mapping?")) return;

    try {
      await axios.delete(`${deleteUrlBase}/${id}`, {
        headers: {
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": csrfToken,
        },
      });

      setMappings(mappings.filter((m) => m.id !== id));
    } catch (err) {
      setError("Failed to remove border mapping. Please try again.");
    }
  };

  return (
    <div className="space-y-6">
      {/* Existing Mappings */}
      {mappings.length > 0 && (
        <div>
          <h3 className="text-sm font-semibold text-slate-900 mb-3">
            Configured Borders
          </h3>
          <div className="border border-slate-200 rounded-lg overflow-hidden">
            <table className="min-w-full divide-y divide-slate-200">
              <thead className="bg-slate-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Paper Type
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Border Width
                  </th>
                  <th className="px-4 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-slate-200">
                {mappings.map((mapping) => (
                  <tr key={mapping.id}>
                    <td className="px-4 py-3 text-sm text-slate-900">
                      {mapping.paper_type_name || `Paper Type #${mapping.paper_type_id}`}
                    </td>
                    <td className="px-4 py-3 text-sm text-slate-600">
                      {mapping.border_width_mm}mm
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => handleDelete(mapping.id)}
                        className="text-sm text-red-600 hover:text-red-800 font-medium"
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {mappings.length === 0 && !loading && (
        <p className="text-sm text-slate-500">
          No border mappings configured yet. Add one below.
        </p>
      )}

      {/* Error */}
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-md p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Add New Mapping */}
      {loading ? (
        <p className="text-sm text-slate-500">Loading paper types...</p>
      ) : (
        <form onSubmit={handleAdd} className="space-y-4">
          <h3 className="text-sm font-semibold text-slate-900">
            Add Border Mapping
          </h3>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 items-end">
            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">
                Paper Type
              </label>
              <select
                value={selectedPaperTypeId}
                onChange={(e) => setSelectedPaperTypeId(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950 text-sm"
              >
                <option value="">Select a paper type...</option>
                {availablePaperTypes.map((pt) => (
                  <option key={pt.id} value={pt.id}>
                    {pt.title}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-700 mb-1">
                Border Width (mm)
              </label>
              <input
                type="number"
                min="1"
                max="100"
                value={borderWidthMm}
                onChange={(e) => setBorderWidthMm(e.target.value)}
                placeholder="e.g. 10"
                className="w-full px-3 py-2 border border-slate-300 rounded-md shadow-sm focus:outline-none focus:ring-slate-950 focus:border-slate-950 text-sm"
              />
            </div>

            <div>
              <button
                type="submit"
                disabled={!selectedPaperTypeId || !borderWidthMm || saving}
                className="w-full px-4 py-2 bg-slate-900 text-white rounded-md text-sm font-medium hover:bg-slate-800 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                {saving ? "Saving..." : "Add Border"}
              </button>
            </div>
          </div>

          {availablePaperTypes.length === 0 && paperTypes.length > 0 && (
            <p className="text-xs text-slate-500">
              All available paper types already have border mappings configured.
            </p>
          )}
        </form>
      )}
    </div>
  );
}

export default BorderMappingsManager;
