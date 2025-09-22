const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const readline = require('readline');
const { URL } = require('url');

async function initializeFirebase() {
  try {
    const serviceKeyPath = path.join(__dirname, 'service-key.json');
    
    if (!fs.existsSync(serviceKeyPath)) {
      throw new Error('Arquivo service-key.json não encontrado. Coloque o arquivo na raiz do projeto.');
    }

    const serviceAccount = require(serviceKeyPath);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: `${serviceAccount.project_id}.firebasestorage.app`,
      projectId: serviceAccount.project_id
    });

    console.log(`Firebase inicializado com sucesso para o projeto: ${serviceAccount.project_id}`);
    
  } catch (error) {
    console.error('Erro ao inicializar Firebase:', error.message);
    process.exit(1);
  }
}

function askDocumentId() {
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question('Digite o ID do documento (ex: uKKpxNxE334uY7AZsFbg): ', (answer) => {
      rl.close();
      const docId = answer.trim();
      
      if (!docId) {
        console.log('❌ ID do documento não pode ser vazio!');
        process.exit(1);
      }
      
      resolve(docId);
    });
  });
}

function extractStorageInfo(firebaseUrl, correctProjectId = 'inspection-app-2025') {
  try {
    const url = new URL(firebaseUrl);
    
    if (!url.hostname.includes('firebasestorage.googleapis.com')) {
      throw new Error('URL não é do Firebase Storage');
    }

    const pathParts = url.pathname.split('/');
    let bucket = pathParts[3];
    const objectPath = decodeURIComponent(pathParts[5]);
    
    if (bucket.includes('undefined') || bucket === 'undefined.firebasestorage.app') {
      bucket = `${correctProjectId}.firebasestorage.app`;
    }
    
    const params = new URLSearchParams(url.search);
    const currentToken = params.get('token');
    
    return {
      bucket,
      objectPath,
      currentToken,
      baseUrl: `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(objectPath)}?alt=media`,
      needsCorrection: bucket !== pathParts[3]
    };
  } catch (error) {
    throw new Error(`Erro ao extrair informações da URL: ${error.message}`);
  }
}

function buildNewUrl(baseUrl, newToken) {
  return `${baseUrl}&token=${newToken}`;
}

function isFirebaseStorageUrl(url) {
  try {
    const urlObj = new URL(url);
    return urlObj.hostname.includes('firebasestorage.googleapis.com');
  } catch {
    return false;
  }
}

class StorageService {
  constructor() {
    this.storage = admin.storage();
  }

  async generateNewAccessToken(bucketName, objectPath) {
    try {
      const bucket = this.storage.bucket(bucketName);
      const file = bucket.file(objectPath);
      
      const [exists] = await file.exists();
      if (!exists) {
        throw new Error(`Arquivo não encontrado: ${objectPath}`);
      }

      const [metadata] = await file.getMetadata();
      
      if (metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens) {
        const tokens = metadata.metadata.firebaseStorageDownloadTokens.split(',');
        return tokens[0];
      }

      const newToken = this.generateRandomToken();
      
      await file.setMetadata({
        metadata: {
          firebaseStorageDownloadTokens: newToken
        }
      });

      return newToken;
    } catch (error) {
      if (error.message.includes('permission') || error.message.includes('Permission denied') || error.code === 403) {
        console.log(`Permission denied detectado para ${objectPath} - URL será marcada como inválida`);
        return 'PERMISSION_DENIED';
      }
      console.error(`Erro ao gerar novo token para ${objectPath}:`, error.message);
      throw error;
    }
  }

  generateRandomToken() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  async getValidToken(bucketName, objectPath) {
    try {
      const bucket = this.storage.bucket(bucketName);
      const file = bucket.file(objectPath);
      
      const [metadata] = await file.getMetadata();
      
      if (metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens) {
        const tokens = metadata.metadata.firebaseStorageDownloadTokens.split(',');
        return tokens[0];
      }
      
      return await this.generateNewAccessToken(bucketName, objectPath);
    } catch (error) {
      if (error.message.includes('permission') || error.message.includes('Permission denied') || error.code === 403) {
        console.log(`Permission denied detectado para ${objectPath} - URL será marcada como inválida`);
        return 'PERMISSION_DENIED';
      }
      console.error(`Erro ao obter token válido para ${objectPath}:`, error.message);
      throw error;
    }
  }
}

class FirestoreService {
  constructor(collectionName = 'inspections') {
    this.db = admin.firestore();
    this.collectionName = collectionName;
  }

  async getAllInspections() {
    try {
      console.log(`Buscando documentos na coleção "${this.collectionName}"...`);
      const snapshot = await this.db.collection(this.collectionName).get();
      
      if (snapshot.empty) {
        console.log(`Nenhum documento encontrado na coleção "${this.collectionName}"`);
        return [];
      }

      console.log(`Encontrados ${snapshot.size} documentos`);
      return snapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
      }));
    } catch (error) {
      console.error('Erro ao buscar documentos:', error.message);
      throw error;
    }
  }

  async getSpecificDocument(docId) {
    try {
      console.log(`Buscando documento específico: ${docId}`);
      const docRef = this.db.collection(this.collectionName).doc(docId);
      const doc = await docRef.get();
      
      if (!doc.exists) {
        throw new Error(`Documento ${docId} não encontrado`);
      }

      console.log(`Documento ${docId} encontrado`);
      return {
        id: doc.id,
        data: doc.data()
      };
    } catch (error) {
      console.error(`Erro ao buscar documento ${docId}:`, error.message);
      throw error;
    }
  }

  findFirebaseStorageUrls(obj, path = '') {
    const urls = [];
    
    if (typeof obj === 'string' && isFirebaseStorageUrl(obj)) {
      urls.push({ url: obj, path });
    } else if (Array.isArray(obj)) {
      obj.forEach((item, index) => {
        urls.push(...this.findFirebaseStorageUrls(item, `${path}[${index}]`));
      });
    } else if (obj && typeof obj === 'object') {
      Object.keys(obj).forEach(key => {
        const newPath = path ? `${path}.${key}` : key;
        urls.push(...this.findFirebaseStorageUrls(obj[key], newPath));
      });
    }
    
    return urls;
  }

  findEmptyCloudUrls(obj, path = '', docId = '') {
    const emptyUrls = [];
    
    if (Array.isArray(obj)) {
      obj.forEach((item, index) => {
        emptyUrls.push(...this.findEmptyCloudUrls(item, `${path}[${index}]`, docId));
      });
    } else if (obj && typeof obj === 'object') {
      if (obj.hasOwnProperty('cloudUrl') && (obj.cloudUrl === null || obj.cloudUrl === '')) {
        if (obj.filename && obj.type) {
          emptyUrls.push({
            path: path ? `${path}.cloudUrl` : 'cloudUrl',
            filename: obj.filename,
            type: obj.type,
            mimeType: obj.mimeType,
            isUploaded: obj.isUploaded,
            docId: docId
          });
        }
      }
      
      Object.keys(obj).forEach(key => {
        const newPath = path ? `${path}.${key}` : key;
        emptyUrls.push(...this.findEmptyCloudUrls(obj[key], newPath, docId));
      });
    }
    
    return emptyUrls;
  }

  async updateDocument(docId, updatedData) {
    try {
      const docRef = this.db.collection(this.collectionName).doc(docId);
      await docRef.set(updatedData, { merge: false });
      console.log(`Documento ${docId} atualizado com sucesso`);
    } catch (error) {
      console.error(`Erro ao atualizar documento ${docId}:`, error.message);
      throw error;
    }
  }

  buildUpdateObject(documentData, urlMappings) {
    const updatedData = JSON.parse(JSON.stringify(documentData));
    
    urlMappings.forEach(mapping => {
      const { path, newUrl } = mapping;
      
      if (newUrl === 'PERMISSION_DENIED') {
        console.log(`Removendo URL com permission denied no caminho: ${path}`);
        this.deleteValueAtPath(updatedData, path);
      } else {
        this.setValueAtPath(updatedData, path, newUrl);
      }
    });
    
    return updatedData;
  }

  deleteValueAtPath(obj, path) {
    const keys = path.split(/[\.\[\]]+/).filter(key => key !== '');
    let current = obj;
    
    for (let i = 0; i < keys.length - 1; i++) {
      const key = keys[i];
      if (!isNaN(key)) {
        current = current[parseInt(key)];
      } else {
        current = current[key];
      }
    }
    
    const lastKey = keys[keys.length - 1];
    if (!isNaN(lastKey)) {
      delete current[parseInt(lastKey)];
    } else {
      delete current[lastKey];
    }
  }

  setValueAtPath(obj, path, value) {
    const keys = path.split(/[\.\[\]]+/).filter(key => key !== '');
    let current = obj;
    
    for (let i = 0; i < keys.length - 1; i++) {
      const key = keys[i];
      if (!isNaN(key)) {
        current = current[parseInt(key)];
      } else {
        current = current[key];
      }
    }
    
    const lastKey = keys[keys.length - 1];
    if (!isNaN(lastKey)) {
      current[parseInt(lastKey)] = value;
    } else {
      current[lastKey] = value;
    }
  }

  async getDocumentsWithStorageUrls() {
    try {
      const documents = await this.getAllInspections();
      const documentsWithUrls = [];

      documents.forEach(doc => {
        const urls = this.findFirebaseStorageUrls(doc.data);
        if (urls.length > 0) {
          documentsWithUrls.push({
            id: doc.id,
            data: doc.data,
            storageUrls: urls
          });
        }
      });

      console.log(`Encontrados ${documentsWithUrls.length} documentos com URLs do Firebase Storage`);
      return documentsWithUrls;
    } catch (error) {
      console.error('Erro ao buscar documentos com URLs:', error.message);
      throw error;
    }
  }
}

class UrlGenerator {
  constructor(projectId) {
    this.storage = admin.storage();
    this.projectId = projectId || 'inspection-app-2025';
  }

  generateStoragePath(docId, filename, type) {
    const extension = filename.split('.').pop();
    const baseFilename = filename.replace(`.${extension}`, '');
    
    return `inspections/${docId}/media/${type}/${baseFilename}.${extension}`;
  }

  async generateCloudUrl(docId, filename, type, mimeType) {
    try {
      console.log(`    Gerando URL para: ${filename}`);
      
      const storagePath = this.generateStoragePath(docId, filename, type);
      console.log(`    Caminho no storage: ${storagePath}`);
      
      const bucket = this.storage.bucket();
      const file = bucket.file(storagePath);
      
      const [exists] = await file.exists();
      if (!exists) {
        console.log(`    ❌ Arquivo não existe no storage: ${storagePath}`);
        return null;
      }

      const [metadata] = await file.getMetadata();
      let token;
      
      if (metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens) {
        const tokens = metadata.metadata.firebaseStorageDownloadTokens.split(',');
        token = tokens[0];
        console.log(`    ✓ Token existente encontrado: ${token}`);
      } else {
        token = this.generateRandomToken();
        await file.setMetadata({
          metadata: {
            firebaseStorageDownloadTokens: token
          }
        });
        console.log(`    ✓ Novo token gerado: ${token}`);
      }

      const encodedPath = encodeURIComponent(storagePath);
      const url = `https://firebasestorage.googleapis.com/v0/b/${this.projectId}.firebasestorage.app/o/${encodedPath}?alt=media&token=${token}`;
      
      console.log(`    ProjectId usado: ${this.projectId}`);
      
      console.log(`    ✅ URL gerada com sucesso`);
      return url;

    } catch (error) {
      console.error(`    ❌ Erro ao gerar URL para ${filename}:`, error.message);
      
      if (error.message.includes('permission') || error.message.includes('Permission denied') || error.code === 403) {
        console.log(`    Permission denied detectado para ${filename}`);
        return 'PERMISSION_DENIED';
      }
      
      return null;
    }
  }

  generateRandomToken() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  async verifyFileExists(docId, filename, type) {
    try {
      const storagePath = this.generateStoragePath(docId, filename, type);
      const bucket = this.storage.bucket();
      const file = bucket.file(storagePath);
      
      const [exists] = await file.exists();
      return { exists, storagePath };
    } catch (error) {
      console.error(`Erro ao verificar arquivo ${filename}:`, error.message);
      return { exists: false, storagePath: null };
    }
  }
}

class TokenUpdater {
  constructor(projectId, collectionName = 'inspections') {
    this.storageService = new StorageService();
    this.firestoreService = new FirestoreService(collectionName);
    this.urlGenerator = new UrlGenerator(projectId);
    this.projectId = projectId || 'inspection-app-2025';
    this.collectionName = collectionName;
  }

  async updateDocumentTokens(document) {
    try {
      console.log(`\nProcessando documento: ${document.id}`);
      const urlMappings = [];

      for (const urlInfo of document.storageUrls) {
        try {
          console.log(`  Processando URL existente: ${urlInfo.url}`);
          
          const { bucket, objectPath, currentToken, baseUrl, needsCorrection } = extractStorageInfo(urlInfo.url, 'inspection-app-2025');
          console.log(`    Bucket: ${bucket}`);
          console.log(`    Objeto: ${objectPath}`);
          console.log(`    Token atual: ${currentToken}`);
          
          if (needsCorrection) {
            console.log(`    🔧 Bucket corrigido de undefined para ${bucket}`);
          }

          const validToken = await this.storageService.getValidToken(bucket, objectPath);
          console.log(`    Token válido: ${validToken}`);

          if (validToken === 'PERMISSION_DENIED') {
            urlMappings.push({
              path: urlInfo.path,
              oldUrl: urlInfo.url,
              newUrl: 'PERMISSION_DENIED',
              type: 'update'
            });
            console.log(`    ❌ Permission denied - URL será removida`);
          } else if (currentToken !== validToken || needsCorrection) {
            const newUrl = buildNewUrl(baseUrl, validToken);
            urlMappings.push({
              path: urlInfo.path,
              oldUrl: urlInfo.url,
              newUrl: newUrl,
              type: needsCorrection ? 'fix_bucket' : 'update'
            });
            if (needsCorrection) {
              console.log(`    🔧 Bucket e token serão corrigidos`);
            } else {
              console.log(`    ✓ Token será atualizado`);
            }
          } else {
            console.log(`    ✓ Token já está correto`);
          }

        } catch (error) {
          console.error(`    ✗ Erro ao processar URL: ${error.message}`);
        }
      }

      const emptyCloudUrls = this.firestoreService.findEmptyCloudUrls(document.data, '', document.id);
      console.log(`  Encontrados ${emptyCloudUrls.length} campos cloudUrl vazios`);

      for (const emptyUrl of emptyCloudUrls) {
        try {
          console.log(`  Processando cloudUrl vazio: ${emptyUrl.filename}`);
          
          const generatedUrl = await this.urlGenerator.generateCloudUrl(
            emptyUrl.docId, 
            emptyUrl.filename, 
            emptyUrl.type, 
            emptyUrl.mimeType
          );

          if (generatedUrl === 'PERMISSION_DENIED') {
            console.log(`    ❌ Permission denied para ${emptyUrl.filename} - campo será mantido null`);
          } else if (generatedUrl) {
            urlMappings.push({
              path: emptyUrl.path,
              oldUrl: null,
              newUrl: generatedUrl,
              type: 'generate',
              filename: emptyUrl.filename
            });
            console.log(`    ✅ URL gerada para ${emptyUrl.filename}`);
          } else {
            console.log(`    ❌ Não foi possível gerar URL para ${emptyUrl.filename}`);
          }

        } catch (error) {
          console.error(`    ✗ Erro ao gerar URL para ${emptyUrl.filename}: ${error.message}`);
        }
      }

      if (urlMappings.length > 0) {
        console.log(`  Atualizando ${urlMappings.length} URLs no documento...`);
        
        const updates = this.firestoreService.buildUpdateObject(document.data, urlMappings);
        await this.firestoreService.updateDocument(document.id, updates);
        
        return {
          documentId: document.id,
          updatedUrls: urlMappings.length,
          details: urlMappings
        };
      } else {
        console.log(`  Nenhuma URL precisou ser atualizada`);
        return {
          documentId: document.id,
          updatedUrls: 0,
          details: []
        };
      }

    } catch (error) {
      console.error(`Erro ao processar documento ${document.id}:`, error.message);
      throw error;
    }
  }

  async updateSpecificDocument(docId) {
    try {
      console.log(`=== ANALISANDO DOCUMENTO ESPECÍFICO: ${docId} ===\n`);
      
      const document = await this.firestoreService.getSpecificDocument(docId);
      const urls = this.firestoreService.findFirebaseStorageUrls(document.data);
      const emptyCloudUrls = this.firestoreService.findEmptyCloudUrls(document.data, '', document.id);
      
      console.log(`Encontradas ${urls.length} URLs do Firebase Storage existentes`);
      console.log(`Encontrados ${emptyCloudUrls.length} campos cloudUrl vazios`);
      
      if (urls.length === 0 && emptyCloudUrls.length === 0) {
        console.log('Nenhuma URL do Firebase Storage ou cloudUrl vazio encontrado no documento.');
        return null;
      }

      const documentWithUrls = {
        id: document.id,
        data: document.data,
        storageUrls: urls
      };

      const result = await this.updateDocumentTokens(documentWithUrls);
      
      return result;

    } catch (error) {
      console.error(`Erro ao processar documento ${docId}:`, error.message);
      throw error;
    }
  }
}

async function testSpecificDocument() {
  try {
    console.log('🔥 TESTE - Firebase Storage Token Updater (AMBAS COLEÇÕES)\n');
    
    await initializeFirebase();
    
    const docId = await askDocumentId();
    const collections = ['inspections', 'inspections_data'];
    
    for (const collectionName of collections) {
      console.log(`\n${'='.repeat(60)}`);
      console.log(`🔍 TESTANDO COLEÇÃO: ${collectionName.toUpperCase()}`);
      console.log(`${'='.repeat(60)}`);
      
      const updater = new TokenUpdater('inspection-app-2025', collectionName);
      
      try {
        console.log(`\nAnalisando documento ${docId} na coleção ${collectionName}...\n`);
        
        const result = await updater.updateSpecificDocument(docId);
        
        if (result) {
          console.log('\n=== RESULTADO DO TESTE ===');
          console.log(`Coleção: ${collectionName}`);
          console.log(`Documento: ${result.documentId}`);
          console.log(`URLs processadas: ${result.updatedUrls}`);
          
          if (result.details && result.details.length > 0) {
            console.log('\n=== DETALHES DAS ALTERAÇÕES ===');
            result.details.forEach((detail, index) => {
              console.log(`\n${index + 1}. Campo: ${detail.path}`);
              
              if (detail.type === 'generate') {
                console.log(`   Tipo: ✨ URL gerada para arquivo ${detail.filename}`);
                console.log(`   URL gerada: ${detail.newUrl}`);
              } else if (detail.type === 'fix_bucket') {
                console.log(`   Tipo: 🔧 Bucket e token corrigidos`);
                console.log(`   URL antiga: ${detail.oldUrl || 'null'}`);
                console.log(`   URL nova: ${detail.newUrl}`);
              } else if (detail.type === 'update') {
                if (detail.newUrl === 'PERMISSION_DENIED') {
                  console.log(`   Tipo: ❌ Permission Denied (URL removida)`);
                } else {
                  console.log(`   Tipo: 🔄 Token atualizado`);
                  console.log(`   URL antiga: ${detail.oldUrl || 'null'}`);
                  console.log(`   URL nova: ${detail.newUrl}`);
                }
              }
            });
          }
        } else {
          console.log(`Nenhuma URL do Firebase Storage encontrada no documento da coleção ${collectionName}.`);
        }
        
        console.log(`\n✅ Teste da coleção ${collectionName} concluído!`);
        
      } catch (error) {
        if (error.message.includes('não encontrado')) {
          console.log(`\n⚠️  Documento ${docId} não encontrado na coleção ${collectionName}`);
        } else {
          console.error(`\n❌ Erro ao testar coleção ${collectionName}:`, error.message);
        }
      }
    }
    
    console.log(`\n${'='.repeat(60)}`);
    console.log('🎉 TESTE COMPLETO - AMBAS COLEÇÕES TESTADAS');
    console.log(`${'='.repeat(60)}`);
    
  } catch (error) {
    console.error('\n❌ Erro durante o teste:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  testSpecificDocument();
}

module.exports = { testSpecificDocument };