require "rails_helper"

RSpec.describe "Matching", type: :model do
  it "matchers users up well" do
    user1 = create(:user)
    user2 = create(:user)

    user1.messages.create(role: "user", content: "hello")
    user2.messages.create(role: "user", content: "Hi there")

    user1.embed
    user2.embed

    MATCHING_DEFAULT_PROMPT =
      <<~HEREDOC
        For the current user conversation, find the single best matching user conversation.
        The best matching conversation is the one we would most want to refer to when speaking with the current user.
        The best matching conversation could be interesting or funny or relevant or useful in some way.

        ---

        Current user conversation:
        {{current_user_conversation}}

        ---

        Other user conversations:
        {{similar_conversations}}

        Return only the username of the best conversation.
      HEREDOC

    expect(user1.find_match(MATCHING_DEFAULT_PROMPT)).to eq user2
  end

  describe "diverse conversation matching" do
    CONVERSATIONS = JSON.parse(File.read(Rails.root.join("spec/fixtures/conversations.json")))

    MATCHING_PROMPT =
      <<~HEREDOC
        Find the best conversation match for a social connection app.

        Given the CURRENT USER's conversation, identify which OTHER USER would be most valuable to connect them with.
        
        Consider: What could we tell the current user about the matched person that would genuinely matter to them?
        
        The best match is someone whose experience is directly relevant - not just topically similar, but meaningfully connected to what the current user cares about or needs.

        Examples of good matches:
        - Someone learning piano → someone who teaches music lessons
        - Someone moving to Austin → someone who just moved there and knows the neighborhoods
        - Someone going through a divorce → someone who rebuilt their life after one
        - Someone looking for a co-founder → someone with a complementary skillset seeking the same

        ---

        CURRENT USER conversation:
        {{current_user_conversation}}

        ---

        OTHER USER conversations:
        {{similar_conversations}}

        Return ONLY the username of the single best match.
      HEREDOC

    def create_conversation(user, turns)
      turns.each do |(user_msg, assistant_msg)|
        user.messages.create!(role: "user", content: user_msg)
        user.messages.create!(role: "assistant", content: assistant_msg)
      end
    end

    # Create all 20 users from fixture
    CONVERSATIONS.keys.each do |username|
      let!(username.to_sym) do
        user = create(:user, instagram_username: username)
        create_conversation(user, CONVERSATIONS[username])
        user
      end
    end

    let!(:all_users) do
      CONVERSATIONS.keys.map { |username| send(username.to_sym) }
    end

    before do
      all_users.each(&:embed)
    end

    # sarah_runs: marathon training, manages anxiety with running + therapy
    # priya_wellness: manages anxiety with meditation + therapy
    # Connection: Both actively managing anxiety with therapy + self-practices
    it "matches sarah with priya based on anxiety management" do
      expect(sarah_runs.find_match(MATCHING_PROMPT)).to eq(priya_wellness)
    end

    # kevin_photog: wants to photograph proposals/weddings, needs couples
    # darnell_cooks: planning a proposal, wants it documented
    # Connection: Kevin could photograph Darnell's proposal
    it "matches kevin with darnell based on proposal photography need" do
      expect(kevin_photog.find_match(MATCHING_PROMPT)).to eq(darnell_cooks)
    end

    # jess_designs: freelance designer, unstable income, no retirement, wants stability
    # chloe_influencer: influencer, unstable income, no retirement, wants stability
    # Connection: Same exact financial/career situation
    it "matches jess with chloe based on freelance income instability" do
      expect(jess_designs.find_match(MATCHING_PROMPT)).to eq(chloe_influencer)
    end

    # miguel_music: creative passion (music), day job (barista), wondering if should go full-time
    # kevin_photog: creative passion (photo), day job (accounting), wondering if should go full-time
    # Connection: Same creative career crossroads
    it "matches miguel with kevin based on creative career crossroads" do
      expect(miguel_music.find_match(MATCHING_PROMPT)).to eq(kevin_photog)
    end

    # olivia_vet: healthcare worker dealing with patient death, emotional toll
    # lisa_nursing: healthcare worker dealing with patient death, emotional toll
    # Connection: Same profession challenges
    it "matches olivia with lisa based on healthcare emotional toll" do
      expect(olivia_vet.find_match(MATCHING_PROMPT)).to eq(lisa_nursing)
    end

    # derek_startup: panic attacks, no time for therapy, burning out
    # priya_wellness: used to have panic attacks, manages with therapy + meditation
    # Connection: Priya has solutions to Derek's exact problems
    it "matches derek with priya based on anxiety/panic management" do
      expect(derek_startup.find_match(MATCHING_PROMPT)).to eq(priya_wellness)
    end

    # james_retired: wants to mentor young people, looking for people who need guidance
    # ben_newgrad: struggling job seeker, explicitly wants a mentor
    # Connection: Mentor seeking mentee, mentee seeking mentor
    it "matches james with ben based on mentorship" do
      expect(james_retired.find_match(MATCHING_PROMPT)).to eq(ben_newgrad)
    end

    # nina_flight: dating is impossible due to travel schedule
    # zoe_vegan: dating is impossible due to lifestyle
    # Connection: Both struggling with dating due to lifestyle constraints
    it "matches nina with zoe based on lifestyle dating struggles" do
      expect(nina_flight.find_match(MATCHING_PROMPT)).to eq(zoe_vegan)
    end

    # rachel_mom: has 3yo, wants to connect with other parents in same stage
    # hassan_immigrant: has 8 and 5yo, been through toddler years, gives parenting advice
    # Connection: Parent seeking advice → experienced parent
    it "matches rachel with hassan based on parenting" do
      expect(rachel_mom.find_match(MATCHING_PROMPT)).to eq(hassan_immigrant)
    end
  end
end
