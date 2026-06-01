'use client';

import { useState, useTransition } from 'react';
import {
  createPlanAction,
  deletePlanAction,
  updatePlanAction,
  type PlanInput,
} from '../actions';

export interface PlanRow {
  id: string;
  name: string;
  durationDays: number;
  priceInr: number;
  currency: string;
  sortOrder: number;
  active: boolean;
  popular: boolean;
  tagline: string | null;
}

export function PlansManager({ initialPlans }: { initialPlans: PlanRow[] }) {
  const [editingId, setEditingId] = useState<string | 'new' | null>(null);

  return (
    <div className="space-y-4">
      <div className="overflow-hidden rounded-xl border border-border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-surface text-muted text-left">
            <tr>
              <th className="py-2.5 px-4 font-medium">Order</th>
              <th className="py-2.5 px-4 font-medium">Name</th>
              <th className="py-2.5 px-4 font-medium">Duration</th>
              <th className="py-2.5 px-4 font-medium">Price</th>
              <th className="py-2.5 px-4 font-medium">Tags</th>
              <th className="py-2.5 px-4 font-medium">Status</th>
              <th className="py-2.5 px-4 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            {initialPlans.length === 0 && (
              <tr>
                <td colSpan={7} className="text-muted text-center py-10">
                  No plans yet. Add your first below.
                </td>
              </tr>
            )}
            {initialPlans.map((p) => (
              <tr key={p.id} className="border-t border-border">
                <td className="py-2.5 px-4 text-muted">{p.sortOrder}</td>
                <td className="py-2.5 px-4 font-medium">{p.name}</td>
                <td className="py-2.5 px-4">
                  {p.durationDays} day{p.durationDays === 1 ? '' : 's'}
                </td>
                <td className="py-2.5 px-4">
                  {p.currency} {p.priceInr}
                </td>
                <td className="py-2.5 px-4 text-xs">
                  {p.popular && (
                    <span className="bg-primary/15 text-primary px-1.5 py-0.5 rounded mr-1">
                      Popular
                    </span>
                  )}
                  {p.tagline && (
                    <span className="text-muted">{p.tagline}</span>
                  )}
                </td>
                <td className="py-2.5 px-4">
                  {p.active ? (
                    <span className="text-green-400">Active</span>
                  ) : (
                    <span className="text-muted">Hidden</span>
                  )}
                </td>
                <td className="py-2.5 px-4 text-right">
                  <button
                    onClick={() => setEditingId(p.id)}
                    className="text-primary hover:underline mr-3 text-xs"
                  >
                    Edit
                  </button>
                  <DeleteButton planId={p.id} name={p.name} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {editingId === null && (
        <button
          onClick={() => setEditingId('new')}
          className="bg-primary text-white px-4 py-2 rounded font-medium"
        >
          + Add plan
        </button>
      )}

      {editingId === 'new' && (
        <PlanForm
          mode="create"
          initial={emptyPlan()}
          onClose={() => setEditingId(null)}
        />
      )}
      {editingId &&
        editingId !== 'new' &&
        (() => {
          const plan = initialPlans.find((p) => p.id === editingId);
          if (!plan) return null;
          return (
            <PlanForm
              mode="edit"
              initial={rowToInput(plan)}
              planId={plan.id}
              onClose={() => setEditingId(null)}
            />
          );
        })()}
    </div>
  );
}

function emptyPlan(): PlanInput {
  return {
    name: '',
    durationDays: 30,
    priceInr: 0,
    currency: 'Rs',
    sortOrder: 0,
    active: true,
    popular: false,
    tagline: '',
  };
}

function rowToInput(row: PlanRow): PlanInput {
  return {
    name: row.name,
    durationDays: row.durationDays,
    priceInr: row.priceInr,
    currency: row.currency,
    sortOrder: row.sortOrder,
    active: row.active,
    popular: row.popular,
    tagline: row.tagline ?? '',
  };
}

function PlanForm({
  mode,
  initial,
  planId,
  onClose,
}: {
  mode: 'create' | 'edit';
  initial: PlanInput;
  planId?: string;
  onClose: () => void;
}) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [form, setForm] = useState<PlanInput>(initial);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        setError(null);
        start(async () => {
          try {
            if (mode === 'create') {
              await createPlanAction(form);
            } else if (planId) {
              await updatePlanAction(planId, form);
            }
            onClose();
          } catch (err) {
            setError(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="bg-card border border-border rounded-xl p-5 space-y-4"
    >
      <div className="flex items-baseline justify-between">
        <h2 className="font-semibold">
          {mode === 'create' ? 'New plan' : `Edit plan`}
        </h2>
        <button
          type="button"
          onClick={onClose}
          className="text-muted text-xs hover:text-text"
        >
          Cancel
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <Field label="Name (shown in app)">
          <input
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="e.g. 3 Months"
            className={inputCls}
            autoFocus
          />
        </Field>
        <Field label="Sort order (low first)">
          <input
            type="number"
            value={form.sortOrder ?? 0}
            onChange={(e) =>
              setForm({ ...form, sortOrder: Number(e.target.value) })
            }
            className={inputCls}
          />
        </Field>
        <Field label="Duration (days)">
          <input
            type="number"
            min="1"
            value={form.durationDays}
            onChange={(e) =>
              setForm({ ...form, durationDays: Number(e.target.value) })
            }
            className={inputCls}
          />
        </Field>
        <Field label="Price (whole units)">
          <input
            type="number"
            min="0"
            value={form.priceInr}
            onChange={(e) =>
              setForm({ ...form, priceInr: Number(e.target.value) })
            }
            className={inputCls}
          />
        </Field>
        <Field label="Currency symbol">
          <input
            value={form.currency ?? 'Rs'}
            onChange={(e) => setForm({ ...form, currency: e.target.value })}
            className={inputCls}
          />
        </Field>
        <Field label="Tagline (optional)">
          <input
            value={form.tagline ?? ''}
            onChange={(e) => setForm({ ...form, tagline: e.target.value })}
            placeholder="e.g. Best value"
            className={inputCls}
          />
        </Field>
      </div>

      <div className="flex gap-6 pt-1">
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.active ?? true}
            onChange={(e) => setForm({ ...form, active: e.target.checked })}
          />
          Active (visible to users)
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={form.popular ?? false}
            onChange={(e) =>
              setForm({ ...form, popular: e.target.checked })
            }
          />
          Highlight as Popular
        </label>
      </div>

      {error && <p className="text-danger text-sm">{error}</p>}

      <div className="flex gap-3">
        <button
          type="submit"
          disabled={pending}
          className="bg-primary text-white px-4 py-2 rounded font-medium disabled:opacity-50"
        >
          {pending
            ? 'Saving…'
            : mode === 'create'
            ? 'Create plan'
            : 'Save changes'}
        </button>
        <button
          type="button"
          onClick={onClose}
          className="text-muted text-sm"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

function DeleteButton({ planId, name }: { planId: string; name: string }) {
  const [pending, start] = useTransition();
  return (
    <button
      disabled={pending}
      onClick={() => {
        if (!confirm(`Delete plan "${name}"? This cannot be undone.`)) return;
        start(async () => {
          try {
            await deletePlanAction(planId);
          } catch (err) {
            alert(err instanceof Error ? err.message : String(err));
          }
        });
      }}
      className="text-danger hover:underline text-xs disabled:opacity-50"
    >
      {pending ? '…' : 'Delete'}
    </button>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="text-xs space-y-1">
      <div className="text-muted">{label}</div>
      {children}
    </label>
  );
}

const inputCls =
  'w-full bg-surface border border-border rounded px-3 py-2 text-sm focus:outline-none focus:border-primary';
