import { dirname } from 'path';
import { fileURLToPath } from 'url';
import { FlatCompat } from '@eslint/eslintrc';
import prettier from 'eslint-plugin-prettier';
import tailwindcss from 'eslint-plugin-tailwindcss';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({
  baseDirectory: __dirname,
});

const  eslintConfig = [
 ...compat.extends('next/core-web-vitals', 'next/typescript'),
  {
    plugins: {
      prettier,
      tailwindcss,
    },
    rules: {
      // Prettier como regla ESLint
      'prettier/prettier': 'error',

      // Tailwind ordena clases
      'tailwindcss/classnames-order': 'warn',

      // Buenas prácticas
      '@typescript-eslint/no-unused-vars': ['warn'],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
      'react/react-in-jsx-scope': 'off',
    },
  },
];

export default eslintConfig;
