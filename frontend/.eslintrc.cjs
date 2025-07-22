module.exports = {
  root: true,
  extends: [
    'next',
    'next/core-web-vitals',
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended'
  ],
  plugins: ['@typescript-eslint', 'prettier', 'tailwindcss'],
  rules: {
    '@typescript-eslint/no-unused-vars': ['warn'],
    'prettier/prettier': ['error'],
    'tailwindcss/classnames-order': 'warn',
    'react/react-in-jsx-scope': 'off'
  }
};
