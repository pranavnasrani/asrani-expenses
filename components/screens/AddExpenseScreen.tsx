
import React, { useState, useRef } from 'react';
import { scanReceipt } from '../../services/geminiService';
import { Category, Expense } from '../../types';
import Card from '../ui/Card';
import Button from '../ui/Button';
import Input from '../ui/Input';
import Select from '../ui/Select';
import Spinner from '../ui/Spinner';

interface AddExpenseScreenProps {
  categories: Category[];
  addExpense: (expense: Omit<Expense, 'id'>) => void;
}

const today = new Date().toISOString().split('T')[0];

const ManualEntryForm: React.FC<AddExpenseScreenProps & { initialData?: Partial<Omit<Expense, 'id'>>, onFormSubmit: () => void }> = ({ categories, addExpense, initialData, onFormSubmit }) => {
  const [name, setName] = useState(initialData?.name || '');
  const [amount, setAmount] = useState<string>(initialData?.amount?.toString() || '');
  const [date, setDate] = useState(initialData?.date || today);
  const [categoryId, setCategoryId] = useState(initialData?.categoryId || (categories.length > 0 ? categories[0].id : ''));

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !amount || !categoryId || !date) {
      alert('Please fill all fields');
      return;
    }
    addExpense({
      name,
      amount: parseFloat(amount),
      date,
      categoryId,
    });
    onFormSubmit();
    setName('');
    setAmount('');
    setDate(today);
    setCategoryId(categories.length > 0 ? categories[0].id : '');
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <Input label="Expense Name" type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g., Coffee" required />
      <Input label="Amount" type="number" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" required />
      <Select label="Category" value={categoryId} onChange={(e) => setCategoryId(e.target.value)} required>
        {categories.map((cat) => (
          <option key={cat.id} value={cat.id}>{cat.emoji} {cat.name}</option>
        ))}
      </Select>
      <Input label="Date" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
      <Button type="submit" fullWidth>Add Expense</Button>
    </form>
  );
};


export default function AddExpenseScreen({ categories, addExpense }: AddExpenseScreenProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [scannedData, setScannedData] = useState<Partial<Omit<Expense, 'id'>> | null>(null);
  const [showManualForm, setShowManualForm] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileChange = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    setIsLoading(true);
    setScannedData(null);
    setShowManualForm(false);
    
    const result = await scanReceipt(file, categories);
    
    setIsLoading(false);
    if (result) {
      const matchedCategory = categories.find(c => c.name.toLowerCase() === result.categoryName.toLowerCase());
      setScannedData({
        name: result.name,
        amount: result.amount,
        date: result.date.split('T')[0], // Ensure format is YYYY-MM-DD
        categoryId: matchedCategory?.id || categories.find(c=>c.name==='Other')?.id || '',
      });
      setShowManualForm(true);
    }
    // Reset file input to allow re-selection of the same file
    if (fileInputRef.current) {
        fileInputRef.current.value = "";
    }
  };

  const handleFormSubmit = () => {
    setScannedData(null);
    setShowManualForm(false);
  };

  return (
    <div className="space-y-6">
      <Card>
        <div className="text-center">
            <input
                type="file"
                accept="image/*"
                onChange={handleFileChange}
                className="hidden"
                ref={fileInputRef}
                disabled={isLoading}
            />
            <Button onClick={() => fileInputRef.current?.click()} disabled={isLoading} fullWidth variant="secondary">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                Scan Receipt with AI
            </Button>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-2">Upload a picture of your receipt</p>
        </div>
      </Card>
      
      {isLoading && <div className="flex justify-center items-center"><Spinner /> <p className="ml-2">Analyzing receipt...</p></div>}
      
      <div className="relative flex py-2 items-center">
        <div className="flex-grow border-t border-gray-300 dark:border-gray-600"></div>
        <span className="flex-shrink mx-4 text-gray-400 dark:text-gray-500 text-sm">OR</span>
        <div className="flex-grow border-t border-gray-300 dark:border-gray-600"></div>
      </div>

      {!showManualForm && (
        <Card>
          <h2 className="text-lg font-semibold mb-3 text-gray-800 dark:text-gray-100">Enter Manually</h2>
          <ManualEntryForm categories={categories} addExpense={addExpense} onFormSubmit={()=>{}}/>
        </Card>
      )}

      {showManualForm && scannedData && (
        <Card>
            <h2 className="text-lg font-semibold mb-3 text-gray-800 dark:text-gray-100">Confirm Scanned Details</h2>
            <ManualEntryForm categories={categories} addExpense={addExpense} initialData={scannedData} onFormSubmit={handleFormSubmit} />
        </Card>
      )}
    </div>
  );
}
