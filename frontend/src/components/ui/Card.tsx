import React from 'react';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
}

export function Card({ children, className = '', ...rest }: CardProps) {
  return (
    <div
      className={`bg-white border border-slate-200 rounded-lg shadow-sm ${className}`}
      {...rest}
    >
      {children}
    </div>
  );
}
