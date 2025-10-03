
import React from 'react';
import { Category, TabID } from './types';

export const DEFAULT_CATEGORIES: Category[] = [
  { id: '1', name: 'Groceries', emoji: '🛒' },
  { id: '2', name: 'Transport', emoji: '🚗' },
  { id: '3', name: 'Dining Out', emoji: '🍔' },
  { id: '4', name: 'Shopping', emoji: '🛍️' },
  { id: '5', name: 'Utilities', emoji: '💡' },
  { id: '6', name: 'Entertainment', emoji: '🎬' },
  { id: '7', name: 'Health', emoji: '❤️‍🩹' },
  { id: '8', name: 'Other', emoji: '📦' },
];

export const TABS = [
    { 
        id: TabID.ADD, 
        label: 'Add Expense', 
        icon: (active: boolean) => (
            // FIX: Replaced JSX with React.createElement to be valid in a .ts file.
            React.createElement('svg', { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: active ? 'currentColor' : 'none', stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", className: "w-7 h-7" },
                React.createElement('path', { d: "M12 5v14m-7-7h14" })
            )
        )
    },
    { 
        id: TabID.LIST, 
        label: 'Expenses', 
        icon: (active: boolean) => (
            // FIX: Replaced JSX with React.createElement to be valid in a .ts file.
            React.createElement('svg', { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: active ? 'currentColor' : 'none', stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", className: "w-7 h-7" },
                React.createElement('rect', { x: "3", y: "4", width: "18", height: "18", rx: "2", ry: "2" }),
                React.createElement('line', { x1: "16", y1: "2", x2: "16", y2: "6" }),
                React.createElement('line', { x1: "8", y1: "2", x2: "8", y2: "6" }),
                React.createElement('line', { x1: "3", y1: "10", x2: "21", y2: "10" })
            )
        )
    },
    { 
        id: TabID.CHARTS, 
        label: 'Charts', 
        icon: (active: boolean) => (
            // FIX: Replaced JSX with React.createElement to be valid in a .ts file.
            React.createElement('svg', { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: active ? 'currentColor' : 'none', stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", className: "w-7 h-7" },
                React.createElement('path', { d: "M21.21 15.89A10 10 0 1 1 8 2.83" }),
                React.createElement('path', { d: "M22 12A10 10 0 0 0 12 2v10z" })
            )
        )
    },
    { 
        id: TabID.BUDGET, 
        label: 'Budget', 
        icon: (active: boolean) => (
            // FIX: Replaced JSX with React.createElement to be valid in a .ts file.
            React.createElement('svg', { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", fill: active ? 'currentColor' : 'none', stroke: "currentColor", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round", className: "w-7 h-7" },
                React.createElement('path', { d: "M19 5c-1.5 0-2.8 1.4-3 2-3.5-1.5-11-.3-11 5 0 1.8 0 3 2 4.5V20h4v-2h3v2h4v-4c1-.5 1.7-1 2-2h2v-4h-2c0-1-.5-2-2-3zM9 18H7v-4h2v4zm8 0h-2v-4h2v4zm-3-5H7v-2h7v2z" })
            )
        )
    }
];
