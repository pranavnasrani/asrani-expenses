
import React, { useMemo, useState } from 'react';
import { Category, Expense } from '../../types';
import Card from '../ui/Card';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Modal from '../ui/Modal';

interface BudgetScreenProps {
  budget: number;
  setBudget: React.Dispatch<React.SetStateAction<number>>;
  expenses: Expense[];
  categories: Category[];
  addCategory: (category: Omit<Category, 'id'>) => void;
  deleteCategory: (id: string) => void;
}

export default function BudgetScreen({ budget, setBudget, expenses, categories, addCategory, deleteCategory }: BudgetScreenProps) {
  const [newCategoryName, setNewCategoryName] = useState('');
  const [newCategoryEmoji, setNewCategoryEmoji] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  
  const budgetData = useMemo(() => {
    const today = new Date();
    const currentMonth = today.getMonth();
    const currentYear = today.getFullYear();
    
    const lastMonthDate = new Date(today);
    lastMonthDate.setMonth(lastMonthDate.getMonth() - 1);
    const lastMonth = lastMonthDate.getMonth();
    const lastMonthYear = lastMonthDate.getFullYear();

    const expensesThisMonth = expenses.filter(e => {
        const d = new Date(e.date);
        return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
    });

    const expensesLastMonth = expenses.filter(e => {
        const d = new Date(e.date);
        return d.getMonth() === lastMonth && d.getFullYear() === lastMonthYear;
    });

    const spentThisMonth = expensesThisMonth.reduce((sum, e) => sum + e.amount, 0);
    const spentLastMonth = expensesLastMonth.reduce((sum, e) => sum + e.amount, 0);

    const rollover = Math.max(0, budget - spentLastMonth);
    const totalBudgetThisMonth = budget + rollover;
    const remaining = totalBudgetThisMonth - spentThisMonth;
    
    return { spentThisMonth, rollover, totalBudgetThisMonth, remaining };
  }, [budget, expenses]);

  const handleAddCategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (newCategoryName.trim() && newCategoryEmoji.trim()) {
      addCategory({ name: newCategoryName, emoji: newCategoryEmoji });
      setNewCategoryName('');
      setNewCategoryEmoji('');
      setIsModalOpen(false);
    }
  };

  const remainingPercentage = budgetData.totalBudgetThisMonth > 0 ? (budgetData.remaining / budgetData.totalBudgetThisMonth) * 100 : 0;
  
  return (
    <div className="space-y-6">
      <Card>
        <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100 mb-2">Monthly Budget</h2>
        <div className="flex items-center space-x-2">
            <span className="text-2xl font-bold text-gray-500 dark:text-gray-400">$</span>
            <input type="number" value={budget} onChange={e => setBudget(Number(e.target.value))} className="text-4xl font-bold bg-transparent focus:outline-none w-full"/>
        </div>
      </Card>
      
      <Card>
        <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100 mb-4">This Month's Summary</h2>
        <div className="space-y-4">
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-4">
                <div 
                    className="bg-blue-500 h-4 rounded-full transition-all duration-500" 
                    style={{width: `${Math.max(0, Math.min(100, remainingPercentage))}%`}}>
                </div>
            </div>
            <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                    <p className="text-gray-500 dark:text-gray-400">Total Budget</p>
                    <p className="font-semibold text-lg">${budgetData.totalBudgetThisMonth.toFixed(2)}</p>
                    <p className="text-xs text-gray-400 dark:text-gray-500">(Budget + Rollover)</p>
                </div>
                <div className="text-right">
                    <p className="text-gray-500 dark:text-gray-400">Remaining</p>
                    <p className={`font-semibold text-lg ${budgetData.remaining < 0 ? 'text-red-500' : 'text-green-500'}`}>${budgetData.remaining.toFixed(2)}</p>
                </div>
                <div>
                    <p className="text-gray-500 dark:text-gray-400">Spent</p>
                    <p className="font-semibold">${budgetData.spentThisMonth.toFixed(2)}</p>
                </div>
                <div className="text-right">
                    <p className="text-gray-500 dark:text-gray-400">Rollover</p>
                    <p className="font-semibold">${budgetData.rollover.toFixed(2)}</p>
                </div>
            </div>
        </div>
      </Card>

      <Card>
        <div className="flex justify-between items-center mb-3">
            <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100">Categories</h2>
            <Button onClick={() => setIsModalOpen(true)} size="sm">Add New</Button>
        </div>
        <ul className="space-y-2">
            {categories.map(cat => (
                <li key={cat.id} className="flex justify-between items-center bg-gray-100 dark:bg-gray-800 p-3 rounded-lg">
                    <span className="font-medium">{cat.emoji} {cat.name}</span>
                    <button onClick={() => deleteCategory(cat.id)} className="text-gray-400 hover:text-red-500 transition-colors">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" strokeLinejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                    </button>
                </li>
            ))}
        </ul>
      </Card>

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Add New Category">
        <form onSubmit={handleAddCategory} className="space-y-4">
            <Input label="Category Name" value={newCategoryName} onChange={e => setNewCategoryName(e.target.value)} placeholder="e.g., Investments" required />
            <Input label="Emoji" value={newCategoryEmoji} onChange={e => setNewCategoryEmoji(e.target.value)} placeholder="e.g., 📈" required maxLength={2} />
            <div className="flex justify-end space-x-2 pt-2">
                <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
                <Button type="submit">Add Category</Button>
            </div>
        </form>
      </Modal>
    </div>
  );
}
