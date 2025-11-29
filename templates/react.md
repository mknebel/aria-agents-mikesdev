# React Project Rules

## File Structure
- Components: `src/components/`
- Pages/Views: `src/pages/` or `src/views/`
- Hooks: `src/hooks/`
- Context: `src/context/`
- Utils: `src/utils/`
- Types: `src/types/`
- Tests: `src/__tests__/` or colocated `*.test.tsx`

## Conventions
- Components: PascalCase (`UserProfile.tsx`)
- Hooks: camelCase with `use` prefix (`useAuth.ts`)
- Utils: camelCase (`formatDate.ts`)
- One component per file
- Named exports preferred over default

## Common Patterns
```tsx
// Functional component with TypeScript
interface Props {
  title: string;
  onSubmit: (data: FormData) => void;
}

export function MyComponent({ title, onSubmit }: Props) {
  const [state, setState] = useState<string>('');

  return <div>{title}</div>;
}

// Custom hook
export function useCustomHook() {
  const [data, setData] = useState(null);
  useEffect(() => { /* ... */ }, []);
  return { data };
}
```

## Testing
```bash
npm test                    # Watch mode
npm test -- --coverage      # With coverage
npm test -- MyComponent     # Specific test
```

## State Management
- Local state: `useState`
- Shared state: Context or Zustand/Redux
- Server state: React Query / SWR
