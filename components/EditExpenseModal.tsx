import React, { useState, useEffect } from 'react';
import { Expense, Category } from '../types';
import Modal from './ui/Modal';
import Input from './ui/Input';
import Select from './ui/Select';
import Button from './ui/Button';

interface EditExpenseModalProps {
  expense: Expense;
  categories: Category[];
  onUpdate: (expense: Expense) => void;
  onClose: () => void;
}

export default function EditExpenseModal({ expense, categories, onUpdate, onClose }: EditExpenseModalProps) {
  const [name, setName] = useState(expense.name);
  const [amount, setAmount] = useState<string>(expense.amount.toString());
  const [date, setDate] = useState(expense.date);
  const [categoryId, setCategoryId] = useState(expense.categoryId);

  useEffect(() => {
    setName(expense.name);
    setAmount(expense.amount.toString());
    setDate(expense.date);
    setCategoryId(expense.categoryId);
  }, [expense]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !amount || !categoryId || !date) {
      alert('Please fill all fields');
      return;
    }
    onUpdate({
      ...expense,
      name,
      amount: parseFloat(amount),
      date,
      categoryId,
    });
  };

  return (
    <Modal isOpen={true} onClose={onClose} title="Edit Expense">
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input label="Expense Name" type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g., Coffee" required />
        <Input label="Amount" type="number" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" required />
        <Select label="Category" value={categoryId} onChange={(e) => setCategoryId(e.target.value)} required>
          {categories.map((cat) => (
            <option key={cat.id} value={cat.id}>{cat.emoji} {cat.name}</option>
          ))}
        </Select>
        <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
        <div className="flex justify-end space-x-2 pt-2">
          <Button type="button" variant="secondary" onClick={onClose}>Cancel</Button>
          <Button type="submit">Save Changes</Button>
        </div>
      </form>
    </Modal>
  );
}
