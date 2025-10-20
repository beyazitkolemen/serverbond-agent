/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./resources/**/*.blade.php",
    "./resources/**/*.js",
    "./resources/**/*.vue",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f5f7ff',
          100: '#ebf0ff',
          200: '#d6e0ff',
          300: '#b8c9ff',
          400: '#94a8ff',
          500: '#667eea',
          600: '#5568d3',
          700: '#4553b8',
          800: '#364199',
          900: '#2a3580',
        },
      },
    },
  },
  plugins: [],
}
