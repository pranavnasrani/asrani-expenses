import React, { useMemo } from 'react';
import { Expense, Category } from '../../types';
import Card from '../ui/Card';

interface ExpensesListScreenProps {
  expenses: Expense[];
  categories: Category[];
  deleteExpense: (id: string) => void;
  onEdit: (expense: Expense) => void;
}

const formatDateForDisplay = (dateString: string) => {
    const date = new Date(dateString);
    // Using en-GB locale to get dd/mm/yyyy format.
    return new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC' }).format(date);
};

export default function ExpensesListScreen({ expenses, categories, deleteExpense, onEdit }: ExpensesListScreenProps) {
  const categoryMap = useMemo(() => {
    return categories.reduce((acc, cat) => {
      acc[cat.id] = cat;
      return acc;
    }, {} as Record<string, Category>);
  }, [categories]);

  const groupedExpenses = useMemo(() => {
    return expenses.reduce((acc, expense) => {
      const date = expense.date; // Group by YYYY-MM-DD for correct sorting
      if (!acc[date]) {
        acc[date] = [];
      }
      acc[date].push(expense);
      return acc;
    }, {} as Record<string, Expense[]>);
  }, [expenses]);
  
  const sortedGroupKeys = Object.keys(groupedExpenses).sort().reverse();
  
  if (expenses.length === 0) {
    return (
        <Card>
            <div className="text-center py-12">
                <svg xmlns="http://www.w3.org/2000/svg" className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <h3 className="mt-2 text-lg font-medium text-gray-900 dark:text-white">No expenses yet</h3>
                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Get started by adding a new expense.</p>
            </div>
        </Card>
    );
  }

  return (
    <div className="space-y-6">
      {sortedGroupKeys.map(date => (
        <div key={date}>
          <h2 className="text-sm font-semibold text-gray-500 dark:text-gray-400 mb-2 px-1">{formatDateForDisplay(date)}</h2>
          <Card className="p-0">
            <ul className="divide-y divide-gray-200 dark:divide-gray-700">
              {groupedExpenses[date].map((expense, index) => (
                <li key={expense.id} className="p-4 flex items-center justify-between group">
                  <div className="flex items-center space-x-4">
                    <span className="text-2xl">{categoryMap[expense.categoryId]?.emoji || '❓'}</span>
                    <div>
                      <p className="font-semibold text-gray-900 dark:text-white">{expense.name}</p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">{categoryMap[expense.categoryId]?.name || 'Uncategorized'}</p>
                    </div>
                  </div>
                   <div className="flex items-center space-x-3">
                    <p className="font-semibold text-gray-900 dark:text-white">${expense.amount.toFixed(2)}</p>
                     <div className="flex items-center opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => onEdit(expense)} className="text-blue-500 p-1" aria-label={`Edit ${expense.name}`}>
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                              <path d="M17.414 2.586a2 2 0 00-2.828 0L7 10.172V13h2.828l7.586-7.586a2 2 0 000-2.828z" />
                              <path fillRule="evenodd" d="M2 6a2 2 0 012-2h4a1 1 0 010 2H4v10h10v-4a1 1 0 112 0v4a2 2 0 01-2 2H4a2 2 0 01-2-2V6z" clipRule="evenodd" />
                            </svg>
                        </button>
                        <button onClick={() => deleteExpense(expense.id)} className="text-red-500 p-1" aria-label={`Delete ${expense.name}`}>
                           <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                             <path fillRule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clipRule="evenodd" />
                           </svg>
                        </button>
                     </div>
                   </div>
                </li>
              ))}
            </ul>
          </Card>
        </div>
      ))}
    </div>
  );
}