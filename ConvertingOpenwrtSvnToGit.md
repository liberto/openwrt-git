# Step 1: Get a clone of openwrt subversion repository #

As the process of converting to git is network intensive, error prone and time
consuming I suggest you fetch your own clone of openwrt repository.
This step is optional.

To grab your copy:
  1. create subversion repository: `svnadmin create file://$HOME/svn/openwrt`
  1. edit/create `pre-revprop-change` hook so svnsync can clone to your repo; putting single `exit 0` will suffice; see [svnsync.txt](http://svn.apache.org/repos/asf/subversion/trunk/notes/svnsync.txt) for more information
  1. initiate for svnsync: `svnsync init file://$HOME/svn/openwrt svn://svn.openwrt.org/openwrt`
  1. fetch the repo: `svnsync sync file://$HOME/svn/openwrt`
  1. You can later issue the above command to fetch all changes from original repo.

Initial synchronization took several hours. Check download section for more or
less current initial copy.

If you locked yourself out of the clone issue:
<pre>
svn pdel --revprop -r 0 svn:sync-lock file://$HOME/svn/openwrt<br>
</pre>
to remove dangling lock.

# Step 2: Convert to git using git-svn #

This step took over 24hrs on my not so decent PC (~ year 2006).
Prepare yourself for long wait.

<pre>
git svn clone --use-log-author --no-metadata \<br>
-T trunk -t tags -b branches \<br>
file://$HOME/svn/openwrt<br>
</pre>

This will grab main development trunk, branches and tags from appropriate
places.

To prepare repository for packages use the following command:
<pre>
git svn clone --use-log-author --no-metadata \<br>
-T packages -t tags -b branches \<br>
file://$HOME/svn/openwrt<br>
</pre>


# Step 3: Clean up tags #

The tags end up as git branches. You can create tags for them.
To list potential tags issue:

<pre>
git branch -r | grep tags/<br>
</pre>

I chose the following tags from the list I obtained above:
  * 8.09
  * 8.09.1
  * 8.09.2
  * 8.09\_rc1
  * 8.09\_rc2
  * BUILDROOT\_20050116
  * TESTED
  * TESTED\_042305
  * backfire\_10.03
  * backfire\_10.03.1
  * kamikaze\_7.06
  * kamikaze\_7.07
  * kamikaze\_7.09
  * kamikaze\_pre1
  * whiterussian\_0.9
  * whiterussian\_rc1
  * whiterussian\_rc2
  * whiterussian\_rc3
  * whiterussian\_rc4
  * whiterussian\_rc5
  * whiterussian\_rc6

To create tag:
<pre>
git tag <tagname> remotes/tags/<tagname><br>
</pre>

# Step 4: Create bare git repo #

You may prepare your own bare repo:
<pre>
git init --bare openwrt.git<br>
cd openwrt.git<br>
git symbolic-ref HEAD refs/heads/trunk<br>
</pre>

`git symbolic-ref HEAD refs/heads/trunk` command will ensure that when you
clone from this repo you will checkout correct (trunk) branch. You don't have
this option with hosting service like google code.

# Step 5: Push to bare git repo #

<pre>
cd <path-to-openwrt><br>
git remote add bare <path-to-openwrt.git><br>
git config --unset remote.bare.fetch<br>
</pre>

Edit .git/config. Add the following lines:
<pre>
push = refs/remotes/8.09:refs/heads/8.09<br>
push = refs/remotes/BUILDROOT:refs/heads/BUILDROOT<br>
push = refs/remotes/NETGEAR:refs/heads/NETGEAR<br>
push = refs/remotes/backfire:refs/heads/backfire<br>
push = refs/remotes/buildroot-ng:refs/heads/buildroot-ng<br>
push = refs/remotes/kamikaze-before-brng:refs/heads/kamikaze-before-brng<br>
push = refs/remotes/trunk:refs/heads/trunk<br>
push = refs/remotes/v20040509:refs/heads/v20040509<br>
push = refs/remotes/vodka:refs/heads/vodka<br>
push = refs/remotes/whiterussian:refs/heads/whiterussian<br>
</pre>
in remote "bare" section.

I prepared the above lines from what I saw in both git and subversion
repository. This will put "remote" branches from git-svn repo as
local branches in bare repo. The list is filtered not to include docs,
feeds and packages directories from the original subversion repo.
I may consider converting packages in the future.

Push to bare repo:
<pre>
git push bare<br>
git push --tags bare<br>
</pre>

You can use bare git repo as your upstream. If you wish to push to repository
on the Internet, like google code, please go on.

To clone from the bare repo:
<pre>
git clone <location-of-bare-repo><br>
</pre>
This will checkout trunk branch for you.

# Step 6: Push to hosted git repo #

The setup is basically the same as for your bare repo. The only major difference
is that you cannot corrctly set head for hosted repository. Therefore to clone
from hosted repository you need to issue:
<pre>
git clone <location-of-hosted-repo> -b trunk<br>
</pre>
which will checkout trunk branch for you.

# You are done! #

# Final notes #
  * You can use git-svn repo to pull the changes from subversion and push them to your upstreams.
  * You can use your subversion copy to pull the rest of components of openwrt tree.
  * Use --authors-file to provide meaningful commit information to git.