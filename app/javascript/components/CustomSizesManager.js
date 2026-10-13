import React, { useEffect, useState } from "react";
import CustomPrintSizeModal from "./CustomPrintSizeModal";

export default function CustomSizesManager() {
  const [sizes, setSizes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null);
  const [deleting, setDeleting] = useState(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState(null);

  const loadSizes = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch("/custom_print_sizes.json");
      if (!response.ok) throw new Error("Could not load custom sizes. Please try again.");
      setSizes(await response.json());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadSizes(); }, []);

  const deleteSize = async () => {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const response = await fetch(`/custom_print_sizes/${deleting}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      });
      if (!response.ok) throw new Error("Could not delete this size. Please try again.");
      setSizes((current) => current.filter((size) => size.id !== deleting));
      setDeleting(null);
      setNotice("Custom size deleted.");
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const buttonClass = "rounded-md px-3 py-2 text-sm font-medium focus:outline-none focus:ring-2 focus:ring-slate-500 disabled:opacity-50";

  return (
    <div className="space-y-4">
      {error && <div role="alert" className="text-sm text-red-700">{error} <button type="button" onClick={loadSizes} disabled={busy || loading} className="underline">Reload sizes</button></div>}
      {notice && <p role="status" className="text-sm text-green-700">{notice}</p>}
      {loading ? <p role="status" className="text-sm text-slate-600">Loading custom sizes…</p> : sizes.length === 0 ? (
        !error && <p className="text-sm text-slate-600">You have no custom sizes yet. Sizes defined during product selection will appear here.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-200 text-slate-600">
              <tr><th scope="col" className="py-3 pr-4">Dimensions</th><th scope="col" className="py-3 pr-4">Material</th><th scope="col" className="py-3 pr-4">Priced as</th><th scope="col" className="py-3 text-right">Actions</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {sizes.map((size) => (
                <tr key={size.id}>
                  <td className="py-3 pr-4 whitespace-nowrap">{size.dimensions_display}</td>
                  <td className="py-3 pr-4">{size.material_type ? (size.material_type === "canvas" ? "Canvas" : "Paper") : "Needs confirmation"}</td>
                  <td className="py-3 pr-4">{size.frame_sku_size_description}</td>
                  <td className="py-3 text-right">
                    {deleting === size.id ? (
                      <div className="space-y-2 max-w-sm ml-auto">
                        <p className="text-sm text-slate-600">Delete this size and its Saved Products entries? Existing product mappings and orders are unaffected.</p>
                        <button type="button" disabled={busy} onClick={() => setDeleting(null)} className={buttonClass}>Cancel</button>
                        <button type="button" disabled={busy} onClick={deleteSize} className={`${buttonClass} text-red-700`}>{busy ? "Deleting…" : "Confirm Delete"}</button>
                      </div>
                    ) : (
                      <div className="flex justify-end gap-2">
                        <button type="button" disabled={busy} onClick={() => { setEditing(size); setDeleting(null); setNotice(null); }} aria-label={`Edit ${size.full_description}`} className={`${buttonClass} text-slate-900 hover:bg-slate-100`}>Edit</button>
                        <button type="button" disabled={busy} onClick={() => { setDeleting(size.id); setNotice(null); }} aria-label={`Delete ${size.full_description}`} className={`${buttonClass} text-red-700 hover:bg-red-50`}>Delete</button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <CustomPrintSizeModal isOpen={Boolean(editing)} editSize={editing}
        apiUrl={window.FramefoxConfig?.apiUrl}
        onClose={() => setEditing(null)}
        onSubmit={(updated) => {
          setSizes((current) => current.map((size) => size.id === updated.id ? updated : size));
          setNotice("Custom size updated.");
        }} />
    </div>
  );
}
