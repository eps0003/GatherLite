shared class Tickets
{
	private uint blueTickets = 0;
	private uint redTickets = 0;
	private uint ticketsPerPlayer;

	void Reset()
	{
		uint playerCount = getGatherMatch().getPlayerCount();
		uint tickets = (playerCount * ticketsPerPlayer) / 2;

		SetBlueTickets(tickets);
		SetRedTickets(tickets);
	}

	void Clear()
	{
		blueTickets = 0;
		redTickets = 0;
	}

	uint getBlueTickets()
	{
		return blueTickets;
	}

	uint getRedTickets()
	{
		return redTickets;
	}

	uint getTickets(u8 team)
	{
		switch (team)
		{
			case 0:
				return getBlueTickets();
			case 1:
				return getRedTickets();
		}
		return 0;
	}

	void SetBlueTickets(uint tickets)
	{
		blueTickets = tickets;
	}

	void SetRedTickets(uint tickets)
	{
		redTickets = tickets;
	}

	bool hasTickets(u8 team)
	{
		return getTickets(team) > 0;
	}

	bool canDecrementTickets()
	{
		return getGatherMatch().isLive() && getRules().isMatchRunning();
	}

	void DecrementTickets(u8 team)
	{
		if (canDecrementTickets())
		{
			switch (team)
			{
				case 0:
					if (getBlueTickets() > 0)
					{
						SetBlueTickets(getBlueTickets() - 1);
					}
					break;
				case 1:
					if (getRedTickets() > 0)
					{
						SetRedTickets(getRedTickets() - 1);
					}
					break;
			}
		}
	}

	void LoadConfig(ConfigFile@ cfg)
	{
		ticketsPerPlayer = cfg.read_u32("tickets_per_player", 8);
	}
}
