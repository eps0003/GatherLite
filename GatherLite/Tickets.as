shared class Tickets
{
	private int blueTickets = 0;
	private int redTickets = 0;
	private int ticketsPerPlayer;
	private uint maxTickets = 999;
	private int ticketTugTickets;

	void Reset()
	{
		uint playerCount = getGatherMatch().getPlayerCount();
		int tickets = ticketsPerPlayer > -1 ? (playerCount * ticketsPerPlayer) / 2 : -1;

		SetBlueTickets(tickets);
		SetRedTickets(tickets);
	}

	void Clear()
	{
		SetBlueTickets(0);
		SetRedTickets(0);
	}

	int getBlueTickets()
	{
		return blueTickets;
	}

	int getRedTickets()
	{
		return redTickets;
	}

	int getTickets(u8 team)
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

	void SetBlueTickets(int tickets)
	{
		blueTickets = Maths::Clamp(tickets, -1, maxTickets);

		if (!hasTickets(0))
		{
			getGatherMatch().CheckWin(0);
		}
	}

	void SetRedTickets(int tickets)
	{
		redTickets = Maths::Clamp(tickets, -1, maxTickets);

		if (!hasTickets(1))
		{
			getGatherMatch().CheckWin(1);
		}
	}

	void SetTickets(u8 team, int tickets)
	{
		switch (team)
		{
			case 0:
				SetBlueTickets(tickets);
				break;
			case 1:
				SetRedTickets(tickets);
				break;
		}
	}

	bool hasTickets(u8 team)
	{
		int tickets = getTickets(team);
		return tickets != 0;
	}

	int getPredictedTickets(u8 team)
	{
		int tickets = getTickets(team);
		if (tickets < 0)
		{
			return tickets;
		}
		return Maths::Max(tickets - getGatherMatch().getDeadCount(team), 0);
	}

	bool canDecrementTickets()
	{
		return getGatherMatch().isLive() && getRules().isMatchRunning();
	}

	void DecrementTickets(u8 team)
	{
		if (canDecrementTickets() && getTickets(team) > 0)
		{
			int tickets = getTickets(team);
			SetTickets(team, tickets - 1);
		}
	}

	void PlaySound(CPlayer@ victim)
	{
		//this is most likely called before victim blob is removed, if they were alive

		GatherMatch@ gatherMatch = getGatherMatch();
		u8 team = victim.getTeamNum();
		int tickets = getPredictedTickets(team);

		if (tickets > -1)
		{
			uint teamSize = gatherMatch.getTeamSize(team);

			if (tickets <= 0)
			{
				Sound::Play("depleted.ogg");
			}
			else if (tickets <= teamSize)
			{
				Sound::Play("depleting.ogg");
			}
		}
	}

	private bool isTicketTugActive(u8 team)
	{
		if (ticketTugTickets < 0) return false;

		int tickets = getPredictedTickets(team);
		if (tickets < 0) return false;

		return tickets <= ticketTugTickets;
	}

	void DoTicketTug(u8 team)
	{
		if (isTicketTugActive(team))
		{
			SetTickets(team, getTickets(team) + 1);
		}
	}

	void RenderHUD()
	{
		CRules@ rules = getRules();

		int blueTickets = getBlueTickets();
		int redTickets = getRedTickets();

		string blueText = blueTickets < 0 ? "Infinite" : ("" + blueTickets);
		string redText = redTickets < 0 ? "Infinite" : ("" + redTickets);

		SColor blueColor = rules.getTeam(0).color;
		SColor redColor = rules.getTeam(1).color;

		bool blueTug = isTicketTugActive(0);
		bool redTug = isTicketTugActive(1);

		Vec2f pos(440, getScreenHeight() - 100);

		GUI::DrawTextCentered("Spawns Remaining", pos, color_white);
		GUI::DrawTextCentered("" + blueText + (blueTug ? "*" : ""), pos + Vec2f(-30, 20), blueColor);
		GUI::DrawTextCentered("" + redText + (redTug ? "*" : ""), pos + Vec2f(30, 20), redColor);

		if (blueTug || redTug)
		{
			GUI::DrawTextCentered("Ticket tug active", pos + Vec2f(0, 40), SColor(255, 100, 100, 100));
		}
	}

	void LoadConfig(ConfigFile@ cfg)
	{
		ticketsPerPlayer = cfg.read_s32("tickets_per_player", 8);
		ticketTugTickets = cfg.read_s32("ticket_tug_tickets", -1);
	}

	void Serialize(CBitStream@ bs)
	{
		bs.write_s32(blueTickets);
		bs.write_s32(redTickets);
	}

	bool deserialize(CBitStream@ bs)
	{
		return bs.saferead_s32(blueTickets) && bs.saferead_s32(redTickets);
	}
}
