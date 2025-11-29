# Next.js Project Rules

## File Structure (App Router)
- Pages: `app/` (file-based routing)
- Components: `components/` or `app/_components/`
- API Routes: `app/api/`
- Public assets: `public/`

## File Structure (Pages Router)
- Pages: `pages/`
- API Routes: `pages/api/`
- Components: `components/`

## Conventions
- `page.tsx` - Page component
- `layout.tsx` - Shared layout
- `loading.tsx` - Loading UI
- `error.tsx` - Error boundary
- `route.ts` - API route handler

## Common Patterns
```tsx
// Server Component (default in App Router)
export default async function Page() {
  const data = await fetchData();
  return <div>{data}</div>;
}

// Client Component
'use client';
export function InteractiveComponent() {
  const [state, setState] = useState('');
  return <button onClick={() => setState('clicked')}>{state}</button>;
}

// API Route (App Router)
export async function GET(request: Request) {
  return Response.json({ data: 'hello' });
}

// Server Action
'use server';
export async function submitForm(formData: FormData) {
  // Process form
}
```

## Commands
```bash
npm run dev          # Development server
npm run build        # Production build
npm run start        # Start production
npm run lint         # ESLint
```
