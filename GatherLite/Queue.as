shared class Queue
{
	private string[] players;

	Queue(CBitStream@ bs)
	{
		uint count = bs.read_u32();
		players.set_length(count);
		for (uint i = 0; i < count; i++)
		{
			players[i] = bs.read_string();
		}
	}

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
}
