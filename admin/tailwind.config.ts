import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#0a0a0f',
        surface: '#13131a',
        card: '#1a1a24',
        border: '#252535',
        primary: '#9333ea',
        accent: '#ec4899',
        text: '#e5e7eb',
        muted: '#94a3b8',
        success: '#10b981',
        danger: '#ef4444',
      },
    },
  },
  plugins: [],
};

export default config;
