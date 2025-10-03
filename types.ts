
export interface Expense {
  id: string;
  name: string;
  amount: number;
  date: string; // YYYY-MM-DD
  categoryId: string;
}

export interface Category {
  id: string;
  name: string;
  emoji: string;
}

export enum TabID {
  ADD = 'add',
  LIST = 'list',
  CHARTS = 'charts',
  BUDGET = 'budget',
}
