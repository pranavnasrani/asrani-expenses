
import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
}

export default function Card({ children, className = '' }: CardProps) {
  return (
    <div className={`bg-white dark:bg-gray-800/50 p-6 rounded-2xl shadow-sm ${className}`}>
      {children}
    </div>
  );
}
