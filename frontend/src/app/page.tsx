// app/page.tsx (o cualquier otro Server Component)
async function getData() {
  const res = await fetch('http://localhost/api/test', {
    cache: 'no-store', // 👈 evita cache para dev
  });

  console.log(res.url);

  if (!res.ok) {
    throw new Error('Failed to fetch');
  }

  return res.json();
}

export default async function Home() {
  let data: any;
  try {
    data = await getData();
    console.log(data);
  } catch (err) {
    return (
      <main>
        <h1>Test conexión API:</h1>
        <p>❌ Error: {(err as Error).message}</p>
      </main>
    );
  }

  return (
    <main>
      <h1>Test conexión API:</h1>
      <pre>{JSON.stringify(data, null, 2)}</pre>
    </main>
  );
}
