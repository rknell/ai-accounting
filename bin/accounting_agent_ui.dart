import 'package:ai_accounting/agents/accounting_agent_shell.dart';

Future<void> main() async {
  final shell = AccountingAgentShell(
    config: AccountingAgentShellConfig(
      introTitle:
          '🏆 ACCOUNTING AGENT UI: Interactive Transaction Investigation & Resolution [+1000 XP]',
      introDescription:
          'Elite accounting agent with MCP-powered tooling for Rebellion Rum Co.',
      sessionIntro:
          '🎯 INTERACTIVE ACCOUNTING INVESTIGATION SYSTEM\nType \'exit\', \'quit\', or \'done\' to finish the session.',
      promptLabel: '🔍 Enter your accounting investigation',
      specialInstructions: kAccountingAgentStandardSpecialInstructions,
      samplePrompts: const [
        'Find all uncategorised transactions and suggest proper accounts.',
        'Search for fuel expenses in the past 60 days and verify GST handling.',
        'Locate MyPost or Australia Post transactions and code them to Postage (COGS).',
      ],
    ),
  );

  await shell.run();
}
