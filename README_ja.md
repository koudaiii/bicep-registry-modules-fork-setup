# Bicep Registry Modules Fork Setup

Azure Verified Modules (AVM) Bicep プロジェクトへの貢献を開始するために必要なすべてのセットアップを自動化するスクリプトです。

## 概要

このスクリプトは以下の処理を自動化します：

- Azure/bicep-registry-modules リポジトリのフォーク作成
- ローカルへのクローン
- Azure サービスプリンシパル（SPN）またはユーザー割り当てマネージドアイデンティティ（UAMI）の作成
- GitHub Actions 用の認証設定（OIDC または従来の認証）
- GitHub リポジトリのシークレット設定
- ワークフローの有効化と設定

## 前提条件

以下のツールがインストールされ、適切に設定されている必要があります：

- [GitHub CLI (gh)](https://github.com/cli/cli#installation)
- [Azure CLI (az)](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [jq](https://stedolan.github.io/jq/download/)

また、以下の認証が完了している必要があります：

- GitHub CLI: `gh auth login`
- Azure CLI: `az login`

## 使用方法

リポジトリのルートディレクトリから以下のコマンドを実行してください：

```bash
./script/fork-setup.sh [OPTIONS]
```

### 必須パラメータ

- `--repo-path <path>`: フォークしたリポジトリをクローンするパス（ディレクトリが存在しない場合は作成されます）
- `--subscription-id <id>`: テストデプロイメント用の Azure サブスクリプション ID
- `--tenant-id <id>`: Azure テナント ID
- `--token-nameprefix <prefix>`: リソース命名用の短い（3-5 文字）ユニークな文字列

### オプションパラメータ

- `--mgmt-group-id <id>`: 管理グループスコープのデプロイメント用管理グループ ID
- `--spn-name <name>`: サービスプリンシパル名（非 OIDC、非推奨）
- `--uami-name <name>`: ユーザー割り当てマネージドアイデンティティ名
- `--uami-rsg-name <name>`: UAMI 用リソースグループ名（デフォルト: rsg-avm-bicep-brm-fork-ci-oidc）
- `--uami-location <location>`: UAMI とリソースグループの場所
- `--use-oidc <true|false>`: OIDC 認証を使用するか（デフォルト: true）
- `--help`: ヘルプメッセージを表示

## 使用例

### OIDC 認証でサブスクリプションと管理グループスコープのデプロイメント

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --mgmt-group-id "alz" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --uami-location "uksouth"
```

### カスタム UAMI 名での OIDC 認証

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --uami-location "uksouth" \
  --uami-name "my-uami-name" \
  --uami-rsg-name "my-uami-rsg-name"
```

### 非 OIDC 認証（非推奨）

```bash
./script/fork-setup.sh \
  --repo-path "/home/user/repos" \
  --subscription-id "1b60f82b-d28e-4640-8cfa-e02d2ddb421a" \
  --tenant-id "c3df6353-a410-40a1-b962-e91e45e14e4b" \
  --token-nameprefix "ex123" \
  --use-oidc false
```

## スクリプトの動作

1. **前提条件チェック**: GitHub CLI、Azure CLI の認証状態を確認
2. **リポジトリフォーク**: Azure/bicep-registry-modules をフォークしてローカルにクローン
3. **Azure 認証設定**:
   - OIDC 使用時: ユーザー割り当てマネージドアイデンティティとフェデレーテッド資格情報を作成
   - 非 OIDC 使用時: サービスプリンシパルを作成
4. **RBAC 設定**: 必要なスコープ（サブスクリプション、管理グループ）に Owner ロールを割り当て
5. **GitHub 設定**:
   - リポジトリシークレットの設定
   - 環境（avm-validation）の作成
   - ワークフローの有効化
6. **ワークフロー設定**: すべてのワークフローを無効化（貢献ガイドラインに従って）

## 注意事項

- スクリプトは任意の場所から実行可能ですが、このリポジトリのルートから実行することを推奨します
- OIDC 認証の使用を強く推奨します（セキュリティ上の理由）
- 管理グループ ID が提供されない場合、管理グループスコープの権限は設定されません
- スクリプト実行後、GitHub Actions を手動で有効化する必要があります
- セットアップ後、すべてのワークフローが無効化されます（貢献ガイドラインに従って）

## トラブルシューティング

### よくある問題

1. **GitHub CLI 認証エラー**: `gh auth login` で再認証してください
2. **Azure CLI 認証エラー**: `az login` で適切なテナントにログインしてください
3. **権限エラー**: 指定したサブスクリプションに対する Owner 権限があることを確認してください
4. **リソース名の競合**: `--token-nameprefix` にユニークな値を使用してください

### ログの確認

スクリプトは実行中に詳細なログを出力します。エラーが発生した場合は、エラーメッセージを確認して適切に対処してください。

## 参考リンク

- [Azure Verified Modules - Bicep Contribution Flow](https://azure.github.io/Azure-Verified-Modules/contributing/bicep/bicep-contribution-flow/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

## ライセンス

このスクリプトは元の Azure/bicep-registry-modules リポジトリと同じライセンスの下で提供されます。
