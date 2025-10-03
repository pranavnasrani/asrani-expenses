
import React from 'react';

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label: string;
}

export default function Select({ label, id, children, ...props }: SelectProps) {
  const selectId = id || `select-${label.replace(/\s+/g, '-').toLowerCase()}`;
  return (
    <div>
      <label htmlFor={selectId} className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
        {label}
      </label>
      <select
        id={selectId}
        {...props}
        className="w-full px-4 py-3 bg-gray-100 dark:bg-gray-700 border-transparent rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition appearance-none"
      >
        {children}
      </select>
    </div>
  );
}
