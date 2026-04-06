/**
 * TWIZA Moneypenny — Manus.im Integration Module
 * AI agent platform (Meta) — task creation, projects, files, webhooks
 * API Docs: https://open.manus.ai/docs
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const CREDENTIALS_PATH = path.join(process.env.HOME || '', '.config/manus/credentials.json');
const BASE_URL = 'https://api.manus.ai';

function loadCredentials() {
  const creds = JSON.parse(fs.readFileSync(CREDENTIALS_PATH, 'utf8'));
  if (!creds.apiKey) throw new Error('Missing apiKey in credentials');
  return creds;
}

function request(method, endpoint, body = null) {
  const creds = loadCredentials();
  return new Promise((resolve, reject) => {
    const url = new URL(`/v1${endpoint}`, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      path: url.pathname + url.search,
      headers: {
        'API_KEY': creds.apiKey,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode}: ${JSON.stringify(parsed)}`));
          } else {
            resolve(parsed);
          }
        } catch {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// ── Tasks ──

async function createTask(prompt, options = {}) {
  const body = {
    prompt,
    agentProfile: options.agentProfile || 'manus-1.6',
    ...options,
  };
  return request('POST', '/tasks', body);
}

async function getTask(taskId) {
  return request('GET', `/tasks/${taskId}`);
}

async function getTasks(params = {}) {
  const qs = new URLSearchParams(params).toString();
  return request('GET', `/tasks${qs ? '?' + qs : ''}`);
}

async function updateTask(taskId, data) {
  return request('PATCH', `/tasks/${taskId}`, data);
}

async function deleteTask(taskId) {
  return request('DELETE', `/tasks/${taskId}`);
}

// Multi-turn: continue existing task
async function continueTask(taskId, prompt, options = {}) {
  return createTask(prompt, { ...options, taskId });
}

// ── Projects ──

async function createProject(name, instruction = '') {
  return request('POST', '/projects', { name, instruction });
}

async function getProjects() {
  return request('GET', '/projects');
}

// ── Files ──

async function createFile(filename, contentType) {
  return request('POST', '/files', { filename, contentType });
}

async function getFiles() {
  return request('GET', '/files');
}

async function getFile(fileId) {
  return request('GET', `/files/${fileId}`);
}

async function deleteFile(fileId) {
  return request('DELETE', `/files/${fileId}`);
}

// ── Webhooks ──

async function createWebhook(url, events = ['task.completed']) {
  return request('POST', '/webhooks', { url, events });
}

async function deleteWebhook(webhookId) {
  return request('DELETE', `/webhooks/${webhookId}`);
}

// ── OpenAI SDK Compatibility ──

function openaiConfig() {
  const creds = loadCredentials();
  return {
    apiKey: creds.apiKey,
    baseURL: `${BASE_URL}/v1`,
    defaultHeaders: { 'API_KEY': creds.apiKey },
  };
}

module.exports = {
  createTask,
  getTask,
  getTasks,
  updateTask,
  deleteTask,
  continueTask,
  createProject,
  getProjects,
  createFile,
  getFiles,
  getFile,
  deleteFile,
  createWebhook,
  deleteWebhook,
  openaiConfig,
};

// ── CLI test ──
if (require.main === module) {
  (async () => {
    try {
      console.log('Testing Manus API...');
      const result = await createTask('What is 2+2? Reply in one word.', {
        agentProfile: 'manus-1.6-lite',
      });
      console.log('✅ Task created:', JSON.stringify(result, null, 2));

      // Check task status
      if (result.task_id) {
        const task = await getTask(result.task_id);
        console.log('📋 Task details:', JSON.stringify(task, null, 2));
      }
    } catch (e) {
      console.error('❌ Error:', e.message);
    }
  })();
}
