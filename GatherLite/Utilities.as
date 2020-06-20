shared void SendMessage(string message, SColor color)
{
	CBitStream bs;
	bs.write_string(message);
	bs.write_u32(color.color);

	CRules@ rules = getRules();
	rules.SendCommand(rules.getCommandID("server_message"), bs, true);
}

shared void SendMessage(string message, SColor color, CPlayer@ player)
{
	CBitStream bs;
	bs.write_string(message);
	bs.write_u32(color.color);

	CRules@ rules = getRules();
	rules.SendCommand(rules.getCommandID("server_message"), bs, player);
}

shared string listUsernames(string[] usernames)
{
	string text;
	for (uint i = 0; i < usernames.length; i++)
	{
		if (i > 0)
		{
			text += ", ";
		}
		text += usernames[i];
	}
	return text;
}

shared string plural(int value, string word, string suffix = "s")
{
	if (value == 1)
	{
		return word;
	}
	else
	{
		return word + suffix;
	}
}
