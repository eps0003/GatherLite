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
}
