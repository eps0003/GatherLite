shared class Queue
{
	private string[] players;

	bool Add(string username)
	{
		if (!isInQueue(username))
		{
			players.push_back(username);
			return true;
		}
		return false;
	}

	bool Remove(string username)
	{
		int index = players.find(username);
		if (index > -1)
		{
			players.removeAt(index);
			return true;
		}
		return false;
	}

	void Clear()
	{
		players.clear();
	}

	uint getCount()
	{
		return players.length;
	}

	string[] getPlayers()
	{
		return players;
	}

	bool isInQueue(string username)
	{
		for (uint i = 0; i < players.length; i++)
		{
			if (username == players[i])
			{
				return true;
			}
		}
		return false;
	}

	void Serialize(CBitStream@ bs)
	{
		bs.write_u32(players.length);
		for (uint i = 0; i < players.length; i++)
		{
			bs.write_string(players[i]);
		}
	}

	bool deserialize(CBitStream@ bs)
	{
		players.clear();

		uint count;
		if (!bs.saferead_u32(count)) return false;

		for (uint i = 0; i < count; i++)
		{
			string username;
			if (!bs.saferead_string(username)) return false;

			players.push_back(username);
		}

		return true;
	}
}
