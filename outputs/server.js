const express = require('express');
const path = require('node:path');
const { createClient } = require('@supabase/supabase-js');

const app = express();
app.use(express.json({ limit: '1mb' }));
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, ADMIN_KEY } = process.env;
const db = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })
  : null;
app.get('/api/config', (_req,res) => res.json({ url:SUPABASE_URL || '', anonKey:process.env.SUPABASE_ANON_KEY || '' }));
app.get('/api/health', (_req,res) => res.json({ok:Boolean(db)}));
app.get('/api/jobs', async (req,res) => {
  if (!db) return res.status(503).json({error:'Configura Supabase en las variables de entorno.'});
  let query = db.from('jobs').select('*').order('created_at',{ascending:false});
  const {data,error}=await query;
  if(error)return res.status(500).json({error:error.message});
  const q=String(req.query.q||'').trim().toLowerCase(), loc=String(req.query.location||'').trim().toLowerCase();
  const modes=String(req.query.mode||'').split(',').filter(Boolean), min=Number(req.query.minFit||0);
  const jobs=data.map(j=>({...j,description:undefined,desc:j.description,salaryN:j.salary_n})).filter(j=>(!q||[j.title,j.company,...j.skills].join(' ').toLowerCase().includes(q))&&(!loc||j.place.toLowerCase().includes(loc))&&(!modes.length||modes.includes(j.mode))&&(req.query.verified!=='true'||j.verified));
  res.json({jobs,count:jobs.length,minFit:min});
});
app.post('/api/jobs', async (req,res) => {
  if (!db || !ADMIN_KEY || req.get('x-admin-key')!==ADMIN_KEY) return res.status(401).json({error:'Credencial de administración inválida.'});
  const rows=Array.isArray(req.body)?req.body:[req.body];
  if(!rows.length||rows.length>500)return res.status(400).json({error:'Envía de 1 a 500 vacantes.'});
  const norm=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]/g,'');
  const clean=[];
  for(const j of rows){
    if(!j||typeof j.title!=='string'||typeof j.company!=='string'||!j.title.trim()||!j.company.trim())return res.status(400).json({error:'Cada vacante necesita title y company.'});
    clean.push({title:j.title.trim().slice(0,180),company:j.company.trim().slice(0,180),logo:String(j.logo||j.company[0]).slice(0,8),color:String(j.color||'green').slice(0,20),place:String(j.place||'México').slice(0,180),mode:['Remoto','Híbrido','Presencial'].includes(j.mode)?j.mode:'Remoto',salary:String(j.salary||'No publicado').slice(0,100),skills:Array.isArray(j.skills)?j.skills.slice(0,30):[],source:String(j.source||'Importación').slice(0,100),verified:Boolean(j.verified),posted:String(j.posted||'hoy').slice(0,60),recent:Number(j.recent)||0,salaryN:Number(j.salaryN)||0,description:String(j.desc||'').slice(0,2000),url:String(j.url||'').slice(0,1000),dedupe_key:`${norm(j.title)}:${norm(j.company)}:${norm(j.place)}`});
  }
  const {error}=await db.from('jobs').upsert(clean,{onConflict:'dedupe_key'});
  if(error)return res.status(400).json({error:error.message});
  res.status(201).json({saved:clean.length,deduplicated:true});
});
app.get('/',(_req,res)=>res.sendFile(path.join(__dirname,'index.html')));
app.get('/admin',(_req,res)=>res.sendFile(path.join(__dirname,'admin.html')));
app.get('/auth.js',(_req,res)=>res.type('application/javascript').sendFile(path.join(__dirname,'auth.js')));
const port=Number(process.env.PORT||3000);
app.listen(port,()=>console.log(`Brújula disponible en http://localhost:${port}`));
