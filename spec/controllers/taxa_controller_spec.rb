require File.dirname(__FILE__) + '/../spec_helper'

describe TaxaController do
  describe "show" do
    render_views
    let(:taxon) { Taxon.make! }
    elastic_models( Observation )
    it "should 404 for absurdly large ids" do
      get :show, id: "389299563_507aed5ae4_s.jpg"
      expect( response ).to be_not_found
    end

    it "renders a self-referential canonical tag" do
      expect( INatAPIService ).to receive( "get_json" ) { { }.to_json }
      get :show, id: taxon.id
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{taxon_url( taxon, host: Site.default.url )}']" )
    end

    it "renders a canonical tag from other sites to default site" do
      expect( INatAPIService ).to receive( "get_json" ) { { }.to_json }
      different_site = Site.make!
      get :show, id: taxon.id, inat_site_id: different_site.id
      expect( response.body ).to have_tag(
        "link[rel=canonical][href='#{taxon_url( taxon, host: Site.default.url )}']" )
    end
  end

  describe "merge" do
    it "should redirect on succesfully merging" do
      user = make_curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      sign_in user
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(response).to be_redirect
    end

    it "should allow curators to merge taxa they created" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      reject = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).to be_blank
    end

    it "should not allow curators to merge taxa they didn't create" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( creator: curator, rank: Taxon::SPECIES )
      reject = Taxon.make!
      Observation.make!(:taxon => reject)
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).not_to be_blank
    end

    it "should allow curators to merge synonyms" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!(:name => "Foo", rank: Taxon::SPECIES )
      reject = Taxon.make!(:name => "Foo", rank: Taxon::SPECIES )
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).to be_blank
    end

    it "should not allow curators to merge unsynonymous taxa" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      Observation.make!(:taxon => reject)
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).not_to be_blank
    end

    it "should allow curators to merge taxa without observations" do
      curator = make_curator
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).to be_blank
    end

    it "should allow admins to merge anything" do
      curator = make_admin
      sign_in curator
      keeper = Taxon.make!( rank: Taxon::SPECIES )
      reject = Taxon.make!( rank: Taxon::SPECIES )
      post :merge, :id => reject.id, :taxon_id => keeper.id, :commit => "Merge"
      expect(Taxon.find_by_id(reject.id)).to be_blank
    end

    describe "routes" do
      let(:taxon) { Taxon.make! }
      before do
        sign_in make_curator
      end
      it "should accept GET requests" do
        expect(get: "/taxa/#{taxon.to_param}/merge").to be_routable
      end
      it "should accept POST requests" do
        expect(post: "/taxa/#{taxon.to_param}/merge").to be_routable
      end
    end
  end

  describe "destroy" do
    it "should be possible if user did create the record" do
      u = make_curator
      sign_in u
      t = Taxon.make!( creator: u, rank: Taxon::FAMILY )
      delete :destroy, :id => t.id
      expect(Taxon.find_by_id(t.id)).to be_blank
    end

    it "should not be possible if user did not create the record" do
      u = make_curator
      sign_in u
      t = Taxon.make!( rank: Taxon::FAMILY )
      delete :destroy, :id => t.id
      expect(Taxon.find_by_id(t.id)).not_to be_blank
    end

    it "should always be possible for admins" do
      u = make_admin
      sign_in u
      t = Taxon.make!( rank: Taxon::FAMILY )
      delete :destroy, :id => t.id
      expect(Taxon.find_by_id(t.id)).to be_blank
    end

    it "should not be possible for taxa inolved in taxon changes" do
      u = make_curator
      t = Taxon.make!( creator: u, rank: Taxon::FAMILY )
      ts = make_taxon_swap(:input_taxon => t)
      sign_in u
      delete :destroy, :id => t.id
      expect(Taxon.find_by_id(t.id)).not_to be_blank
    end

    it "should not be possible if descendants are associated with taxon changes" do
      u = make_curator
      fam = Taxon.make!( creator: u, rank: Taxon::FAMILY )
      gen = Taxon.make!( creator: u, rank: Taxon::GENUS, parent: fam )
      ts = make_taxon_swap( input_taxon: gen )
      sign_in u
      delete :destroy, id: fam.id
      expect( Taxon.find_by_id( fam.id ) ).not_to be_blank
    end
    it "should not be possible if descendants are associated with taxon change taxa" do
      u = make_curator
      fam = Taxon.make!( creator: u, rank: Taxon::FAMILY )
      gen = Taxon.make!( creator: u, rank: Taxon::GENUS, parent: fam )
      ts = make_taxon_split( input_taxon: gen )
      sign_in u
      delete :destroy, id: fam.id
      expect( Taxon.find_by_id( fam.id ) ).not_to be_blank
    end
  end
  
  describe "update" do
    it "should allow curators to supercede locking" do
      user = make_curator
      sign_in user
      locked_parent = Taxon.make!(locked: true, rank: Taxon::ORDER)
      taxon = Taxon.make!( rank: Taxon::FAMILY )
      put :update, :id => taxon.id, :taxon => {:parent_id => locked_parent.id}
      taxon.reload
      expect(taxon.parent_id).to eq locked_parent.id
    end

    describe "conservation statuses" do
      let(:taxon) { Taxon.make!( rank: Taxon::SPECIES ) }
      let(:user) { make_curator }
      before do
        sign_in user
      end
      it "should allow addition" do
        put :update, id: taxon.id, taxon: {
          conservation_statuses_attributes: {
            1 => {
              status: "EN"
            }
          }
        }
        taxon.reload
        expect( taxon.conservation_statuses.size ).to eq 1
      end
      it "should assign the current user ID as the user_id for new statuses" do
        put :update, id: taxon.id, taxon: {
          conservation_statuses_attributes: {
            1 => {
              status: "EN"
            }
          }
        }
        taxon.reload
        expect( taxon.conservation_statuses.first.user_id ).to eq user.id
      end
      it "should not assign the current user ID as the user_id for existing statuses" do
        cs = ConservationStatus.make!( taxon: taxon )
        put :update, id: taxon.id, taxon: {
          conservation_statuses_attributes: {
            cs.id => {
              status: "EN"
            }
          }
        }
        cs.reload
        expect( cs.user_id ).not_to eq user.id
      end
    end
  end

  describe "autocomplete" do
    elastic_models( Taxon )
    it "should choose exact matches" do
      t = Taxon.make!
      get :autocomplete, q: t.name, format: :json
      expect(assigns(:taxa)).to include t
    end
  end
  
  describe "search" do
    elastic_models( Taxon )
    render_views
    it "should find a taxon by name" do
      t = Taxon.make!( name: "Predictable species", rank: Taxon::SPECIES )
      get :search, q: t.name
      expect(response.body).to be =~ /<span class="sciname">.*?#{t.name}.*?<\/span>/m
    end
    it "should not raise an exception with an invalid per page value" do
      t = Taxon.make!
      get :search, q: t.name, per_page: 'foo'
      expect(response).to be_success
    end
  end

  describe "observation_photos" do
    elastic_models( Observation, Taxon )

    let(:o) { make_research_grade_observation }
    let(:p) { o.photos.first }
    it "should include photos from observations" do
      get :observation_photos, id: o.taxon_id
      expect(assigns(:photos)).to include p
    end

    it "should return photos of an exact taxon match even if there are lots of text matches" do
      t = o.taxon
      other_obs = []
      10.times { other_obs << make_research_grade_observation( description: t.name ) }
      Delayed::Worker.new.work_off
      expect( Taxon.where( name: t.name ).count ).to eq 1
      expect( o.photos.size ).to eq 1
      get :observation_photos, q: t.name
      expect( assigns(:photos).size ).to eq 1
      expect( assigns(:photos) ).to include p
    end

    it "should return photos from Research Grade obs even if there are multiple synonymous taxa" do
      o.taxon.update_attributes( rank: Taxon::SPECIES, parent: Taxon.make!( rank: Taxon::GENUS ) )
      t2 = Taxon.make!( name: o.taxon.name, rank: Taxon::SPECIES, parent: Taxon.make!( rank: Taxon::GENUS ) )
      o2 = make_research_grade_observation( taxon: t2 )
      Delayed::Worker.new.work_off
      expect( Taxon.single_taxon_for_name( o.taxon.name ) ).to be_nil
      get :observation_photos, q: o.taxon.name, quality_grade: Observation::RESEARCH_GRADE
      expect( assigns(:photos) ).to include p
      expect( assigns(:photos) ).to include o2.photos.first
    end
  end

  describe "graft" do
    it "should graft a taxon" do
      genus = Taxon.make!( name: 'Bartleby', rank: Taxon::GENUS )
      species = Taxon.make!( name: 'Bartleby thescrivener', rank: Taxon::SPECIES )
      expect(species.parent).to be_blank
      u = make_curator
      sign_in u
      expect(patch: "/taxa/#{species.to_param}/graft.json").to be_routable
      patch :graft, id: species.id, format: 'json'
      expect(response).to be_success
      species.reload
      expect(species.parent).to eq genus
    end
  end

  describe "set_photos" do
    elastic_models( Observation, Taxon )
    it "should reindex the taxon new photos even if there are existing photos" do
      sign_in User.make!
      taxon = Taxon.make!
      existing_tp = TaxonPhoto.make!( taxon: taxon )
      photo = LocalPhoto.make!
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo.id ).to eq existing_tp.photo.id
      post :set_photos, format: :json, id: taxon.id, photos: [
        { id: photo.id, type: "LocalPhoto", native_photo_id: photo.id },
        { id: existing_tp.photo.id, type: "LocalPhoto", native_photo_id: existing_tp.photo.id }
      ]
      expect( response ).to be_ok
      es_taxon = Taxon.elastic_search( where: { id: taxon.id } ).results.results[0]
      expect( es_taxon.default_photo.id ).to eq photo.id
    end
  end
end
