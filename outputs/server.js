const express = require('express');
const path = require('node:path');
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(express.json({ limit: '1mb' }));
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_KEY } = process.env;
const db = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })
  : null;
const norm = s => String(s || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
const modeForUi = value => norm(value) === 'hibrido' ? 'Hibrido' : value;

app.get('/api/config', (_req, res) => res.json({ url: SUPABASE_URL || '', anonKey: process.env.SUPABASE_ANON_KEY || '' }));
app.get('/api/health', (_req, res) => res.json({ ok: Boolean(db) }));

app.get('/api/jobs', async (req, res) => {
  if (!db) return res.status(503).json({ error: 'Configura Supabase en las variables de entorno.' });
  const { data, error } = await db.from('jobs').select('id,title,company,logo,color,place,mode,salary,skills,source,verified,posted,recent,salary_n,description,url,status,created_at,owner_id').eq('status', 'published').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  const q = String(req.query.q || '').trim().toLowerCase(), loc = String(req.query.location || '').trim().toLowerCase();
  const modes = String(req.query.mode || '').split(',').filter(Boolean);
  const jobs = data.map(({owner_id,...j}) => ({ ...j, internalApply: Boolean(owner_id), description: undefined, desc: j.description, salaryN: j.salary_n, mode: modeForUi(j.mode) }))
    .filter(j => (!q || [j.title, j.company, ...j.skills].join(' ').toLowerCase().includes(q)) && (!loc || j.place.toLowerCase().includes(loc)) && (!modes.length || modes.includes(j.mode)) && (req.query.verified !== 'true' || j.verified));
  res.json({ jobs, count: jobs.length });
});

app.post('/api/jobs', async (req, res) => {
  if (!db || !ADMIN_KEY || req.get('x-admin-key') !== ADMIN_KEY) return res.status(401).json({ error: 'Admin key incorrecta.' });
  const rows = Array.isArray(req.body) ? req.body : [req.body];
  if (!rows.length || rows.length > 500) return res.status(400).json({ error: 'Envia de 1 a 500 vacantes.' });
  const clean = [];
  for (const j of rows) {
    if (!j || typeof j.title !== 'string' || typeof j.company !== 'string' || !j.title.trim() || !j.company.trim()) return res.status(400).json({ error: 'Cada vacante necesita title y company.' });
    clean.push({ title: j.title.trim().slice(0, 180), company: j.company.trim().slice(0, 180), logo: String(j.logo || j.company[0]).slice(0, 8), color: String(j.color || 'green').slice(0, 20), place: String(j.place || 'Mexico').slice(0, 180), mode: ['remoto', 'hibrido', 'presencial'].includes(norm(j.mode)) ? modeForUi(j.mode) : 'Remoto', salary: String(j.salary || 'No publicado').slice(0, 100), skills: Array.isArray(j.skills) ? j.skills.slice(0, 30) : [], source: String(j.source || 'Importacion').slice(0, 100), verified: Boolean(j.verified), posted: String(j.posted || 'hoy').slice(0, 60), recent: Number(j.recent) || 0, salary_n: Number(j.salaryN) || 0, description: String(j.desc || '').slice(0, 2000), url: String(j.url || '').slice(0, 1000), status: 'published', owner_id: null, company_id: null, dedupe_key: `${norm(j.title)}:${norm(j.company)}:${norm(j.place)}` });
  }
  const { error } = await db.from('jobs').upsert(clean, { onConflict: 'dedupe_key' });
  if (error) return res.status(400).json({ error: error.message });
  res.status(201).json({ saved: clean.length, deduplicated: true });
});

function requireAdmin(req, res) {
  if (!db || !ADMIN_KEY || req.get('x-admin-key') !== ADMIN_KEY) { res.status(401).json({ error: 'Admin key incorrecta.' }); return false; }
  return true;
}
app.get('/api/admin/review', async (req, res) => {
  if (!requireAdmin(req, res)) return;
  const [companies, jobs] = await Promise.all([db.from('companies').select('*').eq('status', 'pending').order('created_at'), db.from('jobs').select('*').eq('status', 'pending').order('created_at')]);
  if (companies.error || jobs.error) return res.status(500).json({ error: companies.error?.message || jobs.error?.message });
  res.json({ companies: companies.data, jobs: jobs.data });
});
app.patch('/api/admin/companies/:id', async (req, res) => {
  if (!requireAdmin(req, res)) return;
  const status = ['verified', 'rejected'].includes(req.body.status) ? req.body.status : null;
  if (!status) return res.status(400).json({ error: 'Estado invalido.' });
  const { data, error } = await db.from('companies').update({ status }).eq('id', req.params.id).select().maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Empresa no encontrada.' });
  res.json({ company: data });
});
app.patch('/api/admin/jobs/:id', async (req, res) => {
  if (!requireAdmin(req, res)) return;
  const status = ['published', 'rejected'].includes(req.body.status) ? req.body.status : null;
  if (!status) return res.status(400).json({ error: 'Estado invalido.' });
  if (status === 'published') {
    const { data: job, error: jobError } = await db.from('jobs').select('company_id').eq('id', req.params.id).maybeSingle();
    if (jobError) return res.status(400).json({ error: jobError.message });
    if (job?.company_id) {
      const { data: company, error } = await db.from('companies').select('status').eq('id', job.company_id).maybeSingle();
      if (error || company?.status !== 'verified') return res.status(409).json({ error: 'Primero verifica la empresa.' });
    }
  }
  const { data, error } = await db.from('jobs').update({ status, verified: status === 'published' }).eq('id', req.params.id).select().maybeSingle();
  if (error) return res.status(400).json({ error: error.message });
  if (!data) return res.status(404).json({ error: 'Vacante no encontrada.' });
  res.json({ job: data });
});

app.get('/', (_req, res) => res.sendFile(path.join(__dirname, 'index.html')));
app.get('/admin', (_req, res) => res.sendFile(path.join(__dirname, 'admin.html')));
app.get('/empresas', (_req, res) => res.sendFile(path.join(__dirname, 'empresas.html')));
app.get('/empresas.js', (_req, res) => res.type('application/javascript').sendFile(path.join(__dirname, 'empresas.js')));
app.get('/auth.js', (_req, res) => res.type('application/javascript').sendFile(path.join(__dirname, 'auth.js')));
const port = Number(process.env.PORT || 3000);
app.listen(port, () => console.log(`Brujula disponible en http://localhost:${port}`));
