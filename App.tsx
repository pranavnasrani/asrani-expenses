import React, { useState, useMemo } from 'react';
import { useLocalStorage } from './hooks/useLocalStorage';
import { Expense, Category, TabID } from './types';
import { DEFAULT_CATEGORIES, TABS } from './constants';
import AddExpenseScreen from './components/screens/AddExpenseScreen';
import ExpensesListScreen from './components/screens/ExpensesListScreen';
import ChartsScreen from './components/screens/ChartsScreen';
import BudgetScreen from './components/screens/BudgetScreen';
import NavBar from './components/ui/NavBar';
import EditExpenseModal from './components/EditExpenseModal';

export default function App() {
  const [expenses, setExpenses] = useLocalStorage<Expense[]>('expenses', []);
  const [categories, setCategories] = useLocalStorage<Category[]>('categories', DEFAULT_CATEGORIES);
  const [budget, setBudget] = useLocalStorage<number>('budget', 1000);
  const [activeTab, setActiveTab] = useState<TabID>(TabID.ADD);
  const [editingExpense, setEditingExpense] = useState<Expense | null>(null);

  const addExpense = (expense: Omit<Expense, 'id'>) => {
    const newExpense: Expense = { ...expense, id: Date.now().toString() };
    setExpenses(prev => [newExpense, ...prev]);
  };
  
  const deleteExpense = (id: string) => {
    setExpenses(prev => prev.filter(expense => expense.id !== id));
  };
  
  const updateExpense = (updatedExpense: Expense) => {
    setExpenses(prev => 
      prev.map(expense => 
        expense.id === updatedExpense.id ? updatedExpense : expense
      )
    );
    setEditingExpense(null); // Close modal after update
  };

  const addCategory = (category: Omit<Category, 'id'>) => {
    const newCategory = { ...category, id: Date.now().toString() };
    setCategories(prev => [...prev, newCategory]);
  };
  
  const deleteCategory = (id: string) => {
    // Prevent deletion if category is in use
    if (expenses.some(e => e.categoryId === id)) {
        alert("Cannot delete category as it is currently in use.");
        return;
    }
    setCategories(prev => prev.filter(c => c.id !== id));
  };

  const ScreenComponent = useMemo(() => {
    switch (activeTab) {
      case TabID.ADD:
        return <AddExpenseScreen categories={categories} addExpense={addExpense} />;
      case TabID.LIST:
        return <ExpensesListScreen expenses={expenses} categories={categories} deleteExpense={deleteExpense} onEdit={setEditingExpense} />;
      case TabID.CHARTS:
        return <ChartsScreen expenses={expenses} categories={categories} />;
      case TabID.BUDGET:
        return <BudgetScreen budget={budget} setBudget={setBudget} expenses={expenses} categories={categories} addCategory={addCategory} deleteCategory={deleteCategory} />;
      default:
        return <AddExpenseScreen categories={categories} addExpense={addExpense} />;
    }
  }, [activeTab, expenses, categories, budget]);

  return (
    <div className="min-h-screen font-sans text-gray-800 bg-gray-50 dark:bg-black dark:text-gray-200">
      <div className="max-w-md mx-auto h-screen flex flex-col">
        <header className="p-4 pt-6">
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">{TABS.find(t => t.id === activeTab)?.label}</h1>
        </header>
        
        <main className="flex-grow p-4 overflow-y-auto pb-24">
          {ScreenComponent}
        </main>
        
        <NavBar activeTab={activeTab} setActiveTab={setActiveTab} />
      </div>
      {editingExpense && (
        <EditExpenseModal
          expense={editingExpense}
          categories={categories}
          onUpdate={updateExpense}
          onClose={() => setEditingExpense(null)}
        />
      )}
    </div>
  );
}