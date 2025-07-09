# API de Correção de Gabaritos - Versão Flexível

Esta versão atualizada da API permite correção de gabaritos com **número flexível de questões**, otimizada para integração com frontend existente.

## 🆕 Principais Mudanças

### ✅ Número Flexível de Questões
- **Antes**: Fixo em 44 questões
- **Agora**: Qualquer número de questões (5, 10, 20, 50, etc.)
- O número é determinado automaticamente pelo gabarito oficial fornecido

### ✅ Endpoint Simplificado para Frontend
- Novo endpoint `/corrigir-simples` otimizado para integração
- Resposta mais limpa e direta
- Inclui nota de 0 a 10 automaticamente

### ✅ Validação Inteligente
- Detecta automaticamente o número de questões
- Valida sequência correta (1, 2, 3, ...)
- Mensagens de erro mais claras

## 🚀 Endpoints Atualizados

### 1. Correção Simplificada (NOVO)
**POST** `/api/gabarito/corrigir-simples`

**Payload:**
```json
{
  "gabarito_oficial": {
    "1": "A",
    "2": "B",
    "3": "C"
    // ... quantas questões você quiser
  },
  "imagem": "base64_encoded_image",
  "incluir_detalhes": false  // opcional
}
```

**Resposta:**
```json
{
  "success": true,
  "resultado": {
    "acertos": 8,
    "erros": 2,
    "total_questoes": 10,
    "porcentagem_acerto": 80.0,
    "nota": 8.0
  },
  "problemas": {
    "questoes_multiplas": 1,
    "questoes_em_branco": 0,
    "questoes_nao_detectadas": 1
  }
}
```

### 2. Template Atualizado
**GET** `/api/gabarito/gabarito-template`

**Resposta:**
```json
{
  "opcoes_por_questao": 5,
  "opcoes": ["A", "B", "C", "D", "E"],
  "formato_gabarito_oficial": {
    "exemplo": {
      "1": "A",
      "2": "B",
      "3": "C"
    },
    "descricao": "Número de questões determinado automaticamente"
  },
  "observacoes": [
    "O número de questões é flexível - defina quantas quiser",
    "As questões devem ser numeradas sequencialmente a partir de 1",
    "Cada questão deve ter uma resposta válida: A, B, C, D ou E"
  ]
}
```

### 3. Validação Flexível
**POST** `/api/gabarito/validar-gabarito`

**Resposta:**
```json
{
  "valido": true,
  "erros": [],
  "total_questoes": 15,  // Detectado automaticamente
  "opcoes_validas": ["A", "B", "C", "D", "E"]
}
```

## 📱 Integração com Frontend

### Exemplo de Uso Simples
```javascript
// Frontend JavaScript
async function corrigirGabarito(imagemBase64, gabaritoOficial) {
  const response = await fetch('/api/gabarito/corrigir-simples', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      gabarito_oficial: gabaritoOficial,
      imagem: imagemBase64
    })
  });
  
  const resultado = await response.json();
  
  if (resultado.success) {
    console.log(`Nota: ${resultado.resultado.nota}/10`);
    console.log(`Acertos: ${resultado.resultado.acertos}/${resultado.resultado.total_questoes}`);
  } else {
    console.error('Erro:', resultado.error);
  }
}

// Exemplo de gabarito flexível
const gabarito = {
  "1": "A",
  "2": "B", 
  "3": "C",
  "4": "D",
  "5": "E"
  // Adicione quantas questões precisar
};
```

### Exemplo React/Vue/Angular
```javascript
// Componente de correção
const CorrecaoGabarito = () => {
  const [resultado, setResultado] = useState(null);
  
  const corrigir = async (imagem, gabarito) => {
    try {
      const response = await api.post('/api/gabarito/corrigir-simples', {
        gabarito_oficial: gabarito,
        imagem: imagem
      });
      
      setResultado(response.data);
    } catch (error) {
      console.error('Erro na correção:', error);
    }
  };
  
  return (
    <div>
      {resultado?.success && (
        <div>
          <h3>Resultado da Correção</h3>
          <p>Nota: {resultado.resultado.nota}/10</p>
          <p>Acertos: {resultado.resultado.acertos}/{resultado.resultado.total_questoes}</p>
          <p>Porcentagem: {resultado.resultado.porcentagem_acerto}%</p>
        </div>
      )}
    </div>
  );
};
```

## 🔧 Casos de Uso

### 1. Prova de 10 Questões
```json
{
  "gabarito_oficial": {
    "1": "A", "2": "B", "3": "C", "4": "D", "5": "E",
    "6": "A", "7": "B", "8": "C", "9": "D", "10": "E"
  }
}
```

### 2. Prova de 5 Questões
```json
{
  "gabarito_oficial": {
    "1": "A", "2": "B", "3": "C", "4": "D", "5": "E"
  }
}
```

### 3. Prova de 20 Questões
```json
{
  "gabarito_oficial": {
    "1": "A", "2": "B", ..., "20": "E"
  }
}
```

## ⚡ Vantagens da Versão Flexível

1. **Flexibilidade Total**: Use quantas questões precisar
2. **Integração Simples**: Endpoint otimizado para frontend
3. **Resposta Limpa**: JSON estruturado e fácil de usar
4. **Nota Automática**: Calcula nota de 0 a 10 automaticamente
5. **Validação Inteligente**: Detecta problemas automaticamente
6. **Compatibilidade**: Mantém endpoints anteriores funcionando

## 🔄 Migração da Versão Anterior

Se você estava usando a versão anterior:

**Antes:**
```javascript
// Gabarito fixo de 44 questões
const gabarito = {
  "1": "A", "2": "B", ..., "44": "E"
};
```

**Agora:**
```javascript
// Gabarito flexível - quantas questões quiser
const gabarito = {
  "1": "A", "2": "B", "3": "C", "4": "D", "5": "E"
  // Só as questões que você tem
};
```

## 🧪 Testes

Execute os testes para verificar o funcionamento:

```bash
# Teste básico das funcionalidades
python teste_simples.py

# Teste completo com diferentes números de questões
python teste_flexivel.py
```

## 📞 Suporte

A API mantém compatibilidade com a versão anterior, mas recomendamos usar os novos endpoints para melhor experiência de integração.

