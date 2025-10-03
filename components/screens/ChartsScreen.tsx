
import React, { useMemo } from 'react';
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { Expense, Category } from '../../types';
import Card from '../ui/Card';

interface ChartsScreenProps {
  expenses: Expense[];
  categories: Category[];
}

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8', '#82ca9d', '#ffc658', '#FA8072'];

const CustomTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="bg-white dark:bg-gray-800 p-2 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm">
          <p className="label font-semibold">{`${payload[0].name} : $${payload[0].value.toFixed(2)}`}</p>
        </div>
      );
    }
    return null;
};

export default function ChartsScreen({ expenses, categories }: ChartsScreenProps) {
  const chartData = useMemo(() => {
    const categoryMap = categories.reduce((acc, cat) => {
      acc[cat.id] = cat;
      return acc;
    }, {} as Record<string, Category>);

    const currentMonthExpenses = expenses.filter(expense => {
        const expenseDate = new Date(expense.date);
        const today = new Date();
        return expenseDate.getFullYear() === today.getFullYear() && expenseDate.getMonth() === today.getMonth();
    });

    const dataByCategory = currentMonthExpenses.reduce((acc, expense) => {
      const categoryName = categoryMap[expense.categoryId]?.name || 'Uncategorized';
      if (!acc[categoryName]) {
        acc[categoryName] = 0;
      }
      acc[categoryName] += expense.amount;
      return acc;
    }, {} as Record<string, number>);

    return Object.entries(dataByCategory).map(([name, value]) => ({ name, value }));
  }, [expenses, categories]);

  if (chartData.length === 0) {
    return (
        <Card>
            <div className="text-center py-12">
                <svg xmlns="http://www.w3.org/2000/svg" className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M11 3.055A9.001 9.001 0 1020.945 13H11V3.055z" />
                  <path strokeLinecap="round" strokeLinejoin="round" d="M20.488 9H15V3.512A9.025 9.025 0 0120.488 9z" />
                </svg>
                <h3 className="mt-2 text-lg font-medium text-gray-900 dark:text-white">Not enough data</h3>
                <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Add some expenses for this month to see a chart.</p>
            </div>
        </Card>
    );
  }

  return (
    <Card>
      <h2 className="text-lg font-semibold text-gray-800 dark:text-gray-100 mb-4">This Month's Spending</h2>
      <div style={{ width: '100%', height: 300 }}>
        <ResponsiveContainer>
          <PieChart>
            <Pie
              data={chartData}
              cx="50%"
              cy="50%"
              labelLine={false}
              outerRadius={80}
              fill="#8884d8"
              dataKey="value"
              nameKey="name"
            >
              {chartData.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
              ))}
            </Pie>
            <Tooltip content={<CustomTooltip />} />
            <Legend />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </Card>
  );
}
