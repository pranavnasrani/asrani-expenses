
import React from 'react';
import { TabID } from '../../types';
import { TABS } from '../../constants';

interface NavBarProps {
  activeTab: TabID;
  setActiveTab: (tab: TabID) => void;
}

export default function NavBar({ activeTab, setActiveTab }: NavBarProps) {
  return (
    <nav className="fixed bottom-0 left-0 right-0 max-w-md mx-auto bg-white/70 dark:bg-gray-900/70 backdrop-blur-lg border-t border-gray-200 dark:border-gray-700">
      <div className="flex justify-around items-center h-20">
        {TABS.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex flex-col items-center justify-center w-full transition-colors duration-200 ${
                isActive ? 'text-blue-500' : 'text-gray-500 dark:text-gray-400 hover:text-blue-500'
              }`}
            >
              {tab.icon(isActive)}
              <span className={`text-xs mt-1 font-medium ${isActive ? 'font-bold' : ''}`}>{tab.label}</span>
            </button>
          );
        })}
      </div>
    </nav>
  );
}
