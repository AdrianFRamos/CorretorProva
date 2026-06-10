"""Configuração compartilhada dos testes: banco SQLite isolado por sessão."""

import os
import sys
import tempfile

# Garante que `src` e `tests` sejam importáveis a partir da raiz da API
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Banco temporário definido ANTES de qualquer import de src.main
_tmpdir = tempfile.mkdtemp(prefix='corretor_test_')
os.environ['DATABASE_URL'] = f"sqlite:///{os.path.join(_tmpdir, 'test.db')}"
