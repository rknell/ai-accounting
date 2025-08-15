# 🏆 Accounting Agent UI: Elite Transaction Investigation System

## Overview

The Accounting Agent UI provides an interactive command-line interface for investigating and resolving accounting transaction categorization issues using natural language prompts. It integrates with the Accountant MCP server to provide comprehensive transaction search, analysis, and update capabilities.

## 🚀 Quick Start

### Prerequisites

1. **Environment Setup**:
   ```bash
   export DEEPSEEK_API_KEY="your_deepseek_api_key_here"
   ```

2. **MCP Server Configuration**:
   Ensure `config/mcp_servers.json` is properly configured with the Accountant MCP server.

3. **Chart of Accounts**:
   Verify `inputs/accounts.json` contains your complete chart of accounts.

### Running the Agent UI

```bash
cd ai-accounting
dart run bin/accounting_agent_ui.dart
```

## 🎯 Example Usage Scenarios

### Scenario 1: Staff Wage Categorization
```
🔍 Enter your accounting investigation: all transactions which mention jason crook are to be considered staff wages

⚡ Processing investigation: "all transactions which mention jason crook are to be considered staff wages"
--------------------------------------------------
🏆 INVESTIGATION RESULTS:
I'll help you categorize all transactions mentioning "jason crook" as staff wages. Let me search for these transactions first.

[Agent searches transactions, finds matches, and updates them to account 311 - Staff Wages]

✅ Investigation completed. Ready for next prompt.
```

### Scenario 2: Supplier Categorization
```
🔍 Enter your accounting investigation: transactions from "ABC Supplies" should be categorized as office supplies

⚡ Processing investigation: "transactions from "ABC Supplies" should be categorized as office supplies"
--------------------------------------------------
🏆 INVESTIGATION RESULTS:
I'll search for transactions from ABC Supplies and categorize them as office supplies (account 316).

[Agent processes transactions and updates categorization]

✅ Investigation completed. Ready for next prompt.
```

### Scenario 3: Date Range Analysis
```
🔍 Enter your accounting investigation: review all uncategorized transactions from last month and suggest appropriate accounts

⚡ Processing investigation: "review all uncategorized transactions from last month and suggest appropriate accounts"
--------------------------------------------------
🏆 INVESTIGATION RESULTS:
I'll analyze uncategorized transactions from last month and provide account recommendations based on transaction details and business context.

[Agent analyzes transactions and provides recommendations]

✅ Investigation completed. Ready for next prompt.
```

## 🛡️ Security Features

### Bank Account Protection
- Bank accounts (001-099) are **completely protected** from modification
- The agent will never attempt to change bank account assignments
- All updates preserve the original bank account in transactions

### Audit Trail Preservation
- No transactions are ever deleted
- All changes are logged through the MCP server
- Original transaction data is preserved with update notes

### GST Compliance
- Automatic GST handling based on account settings
- Proper GST splitting for applicable accounts
- GST clearing account (506) automatically managed

## 📊 Available Investigation Types

### 1. String-Based Searches
- Find transactions containing specific text
- Case-sensitive or case-insensitive matching
- Search in descriptions and notes

### 2. Account-Based Analysis
- Review all transactions for specific accounts
- Analyze account usage patterns
- Identify miscategorized transactions

### 3. Date Range Investigations
- Analyze transactions within specific periods
- Monthly, quarterly, or custom date ranges
- Identify trends and patterns

### 4. Amount-Based Queries
- Find transactions within specific amount ranges
- Identify unusual transaction amounts
- Analyze expense patterns

## 🏗️ System Prompt Context

The agent has comprehensive knowledge of:

### Business Context (Rebellion Rum Co)
- Craft distillery operations
- Revenue streams (web, international, shop sales)
- Cost of goods sold categories
- Operating expense structures
- GST registration and compliance

### Chart of Accounts Structure
- Complete account hierarchy
- GST settings for each account
- Account type classifications
- Protected account ranges

### Account Assignment Rules
- Staff payments → Accounts 311-313
- Raw materials → COGS accounts 200-206
- Operating expenses → Expense accounts 300-323
- Revenue → Revenue accounts 100-102
- Owner transactions → Equity accounts 700-701
- Uncertain items → Account 999 (temporary)

## 🔧 Advanced Usage

### Batch Operations
```
🔍 Enter your accounting investigation: find all transactions over $1000 in the last quarter and verify their categorization
```

### Complex Categorization Rules
```
🔍 Enter your accounting investigation: any transaction mentioning "barrel" or "aging" should be categorized as barrels & aging materials (202)
```

### Audit and Compliance
```
🔍 Enter your accounting investigation: review all GST-applicable transactions to ensure proper GST handling
```

## 🚪 Session Management

### Continuing Investigations
- Each session maintains context across multiple prompts
- Previous investigation results inform subsequent queries
- Agent learns from your categorization preferences

### Ending Sessions
Type any of these commands to exit:
- `exit`
- `quit` 
- `done`

## 🛠️ Troubleshooting

### Common Issues

1. **MCP Server Not Found**:
   ```
   ❌ CRITICAL FAILURE: MCP configuration not found at config/mcp_servers.json
   ```
   **Solution**: Ensure MCP server configuration exists and is properly formatted.

2. **Chart of Accounts Missing**:
   ```
   ❌ CRITICAL FAILURE: Chart of accounts not found at inputs/accounts.json
   ```
   **Solution**: Verify the chart of accounts file exists and contains valid JSON.

3. **API Key Issues**:
   ```
   ❌ CRITICAL FAILURE: DEEPSEEK_API_KEY is not set
   ```
   **Solution**: Set the DEEPSEEK_API_KEY environment variable.

### Getting Help

The agent is designed to be conversational. If you're unsure about something, just ask:

```
🔍 Enter your accounting investigation: what accounts are available for equipment purchases?
```

```
🔍 Enter your accounting investigation: show me all transactions that haven't been categorized yet
```

## 🏆 Best Practices

1. **Be Specific**: Provide clear criteria for transaction identification
2. **Use Business Terms**: Reference suppliers, employees, or expense types naturally
3. **Verify Results**: Review agent recommendations before accepting updates
4. **Iterative Approach**: Start with searches, then apply updates once confident
5. **Document Decisions**: Use the notes field to explain categorization reasoning

The Accounting Agent UI transforms complex accounting operations into natural language conversations, making transaction management both powerful and intuitive.
